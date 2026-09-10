# frozen_string_literal: true

require "digest"

# Stable ad identity: the ledger keys impressions on an immutable ad `id`
# instead of the mutable ad text. Ads without an explicit id fall back to
# SHA256(text), which is byte-compatible with the pre-0.4.0 text-keyed
# behavior. Explicit ids give advertisers stable tallies across copy edits.
#
RSpec.describe "stable ad identity" do
  def sha(text)
    Digest::SHA256.hexdigest(text)
  end

  describe "SponsoredLogs::Advertisers.normalize id" do
    it "defaults id to SHA256(text) when no id is given" do
      ad = SponsoredLogs::Advertisers.normalize([{ text: "hello" }]).first
      expect(ad[:id]).to eq(sha("hello"))
    end

    it "uses an explicit id when present" do
      ad = SponsoredLogs::Advertisers.normalize([{ text: "hello", id: "promo-42" }]).first
      expect(ad[:id]).to eq("promo-42")
    end

    it "accepts a string id key from parsed JSON" do
      ad = SponsoredLogs::Advertisers.normalize([{ "text" => "hi", "id" => "promo-7" }]).first
      expect(ad[:id]).to eq("promo-7")
    end

    it "coerces a non-string id and strips surrounding whitespace" do
      ad = SponsoredLogs::Advertisers.normalize([{ text: "hi", id: "  99 " }]).first
      expect(ad[:id]).to eq("99")
    end

    it "falls back to the text hash when id is blank", :aggregate_failures do
      blank = SponsoredLogs::Advertisers.normalize([{ text: "hi", id: "   " }]).first
      empty = SponsoredLogs::Advertisers.normalize([{ text: "hi", id: "" }]).first
      expect(blank[:id]).to eq(sha("hi"))
      expect(empty[:id]).to eq(sha("hi"))
    end
  end

  describe "identity semantics" do
    let(:store) { SponsoredLogs::Ledger::Store::Memory.new }
    let(:ledger) { SponsoredLogs::Ledger::Report.new(store) }

    it "tallies identical copy under different explicit ids separately", :aggregate_failures do
      a = SponsoredLogs::Advertisers.normalize([{ text: "same copy", id: "a" }]).first
      b = SponsoredLogs::Advertisers.normalize([{ text: "same copy", id: "b" }]).first

      3.times { ledger.record(a) }
      ledger.record(b)

      counts = ledger.impression_counts
      expect(counts["a"]).to eq(3)
      expect(counts["b"]).to eq(1)
    end

    it "preserves the tally when copy changes but the id is stable" do
      original = SponsoredLogs::Advertisers.normalize([{ text: "v1 copy", id: "promo" }]).first
      2.times { ledger.record(original) }

      edited = SponsoredLogs::Advertisers.normalize([{ text: "v2 rewritten copy", id: "promo" }]).first
      ledger.record(edited)

      expect(ledger.impression_counts["promo"]).to eq(3)
    end

    it "keys a no-id ad by SHA256(text), matching the pre-0.4.0 behavior" do
      ad = SponsoredLogs::Advertisers.normalize([{ text: "legacy" }]).first
      ledger.record(ad)

      expect(ledger.impression_counts.keys).to eq([sha("legacy")])
    end

    it "shows the latest text for a stable id in the snapshot value" do
      original = SponsoredLogs::Advertisers.normalize([{ text: "old copy", id: "promo", cpm: 5.0 }]).first
      ledger.record(original)
      edited = SponsoredLogs::Advertisers.normalize([{ text: "new copy", id: "promo", cpm: 5.0 }]).first
      ledger.record(edited)

      expect(store.snapshot["promo"][:text]).to eq("new copy")
    end
  end

  describe "cap enforcement keys on id consistently" do
    it "enforces the cap by id: record-key == impression_counts-key == eligible-key", :aggregate_failures do
      now = Time.now
      store = SponsoredLogs::Ledger::Store::Memory.new
      ledger = SponsoredLogs::Ledger::Report.new(store)

      # Capped at 2. Record it twice through the same normalized identity, then
      # confirm the cap lookup (by id) agrees and pick refuses to serve it.
      #
      ad = SponsoredLogs::Advertisers.normalize([{ text: "capped copy", id: "cap-1", cap: 2 }]).first
      2.times { ledger.record(ad) }

      counts = ledger.impression_counts
      expect(counts.keys).to eq(["cap-1"])
      expect(counts["cap-1"]).to eq(2)

      # The id the ledger stored under is the same id eligible looks up, so the
      # cap fires: the capped creative is excluded from the eligible set.
      #
      pool = SponsoredLogs::Advertisers.normalize([{ text: "capped copy", id: "cap-1", cap: 2 }])
      eligible = SponsoredLogs::Advertisers.eligible(pool, now, counts)
      expect(eligible).to be_empty
    end

    it "still serves an ad under its cap when counts are keyed by id" do
      now = Time.now
      picked = SponsoredLogs::Advertisers.pick(
        [{ text: "capped copy", id: "cap-2", cap: 10 }],
        now: now, counts: { "cap-2" => 9 }
      )
      expect(picked[:id]).to eq("cap-2")
    end
  end

  describe "each store keys by id and carries text in the snapshot" do
    shared_examples "an id-keyed store" do
      it "keys the snapshot by id and stores text as a value", :aggregate_failures do
        ad = { id: "promo", text: "the copy", weight: 1, cpm: 8.0 }
        2.times { store.record(ad) }

        snap = store.snapshot
        expect(snap.keys).to eq(["promo"])
        expect(snap["promo"]).to eq(text: "the copy", impressions: 2, cpm: 8.0)
      end

      it "falls back to SHA256(text) for an ad with no id", :aggregate_failures do
        store.record(text: "no id here", weight: 1, cpm: 3.0)

        snap = store.snapshot
        expect(snap.keys).to eq([sha("no id here")])
        expect(snap[sha("no id here")][:text]).to eq("no id here")
      end
    end

    describe SponsoredLogs::Ledger::Store::Memory do
      let(:store) { described_class.new }
      it_behaves_like "an id-keyed store"
    end

    describe SponsoredLogs::Ledger::Store::Redis do
      let(:fake_redis) do
        Class.new do
          def initialize
            @hashes = Hash.new { |h, k| h[k] = {} }
          end

          def hincrby(key, field, by)
            @hashes[key][field] = @hashes[key].fetch(field, 0).to_i + by
          end

          def hset(key, field, value)
            @hashes[key][field] = value.to_s
          end

          def hgetall(key)
            @hashes[key].transform_values(&:to_s)
          end

          def del(*keys)
            keys.each { |k| @hashes.delete(k) }
          end
        end.new
      end

      let(:store) { described_class.new(client: fake_redis) }
      it_behaves_like "an id-keyed store"
    end
  end

  describe "house-ad identification by id" do
    it "computes HOUSE_IDS as the text hashes of the built-in house ads" do
      expected = SponsoredLogs::Advertisers::HOUSE_ADS.map { |ad| sha(ad[:text]) }
      expect(SponsoredLogs::Advertisers::HOUSE_IDS).to eq(expected)
    end

    it "drops house ads by id even after their copy is edited", :aggregate_failures do
      allow(SponsoredLogs.configuration).to receive(:house_ads).and_return(false)

      # A house ad whose TEXT was edited but whose id still resolves to the
      # original house id (explicit id set to the house id).
      #
      house = SponsoredLogs::Advertisers::HOUSE_ADS.first
      house_id = sha(house[:text])
      edited_house = { id: house_id, text: "edited house copy", weight: 1, cpm: 0.0 }
      paid = { id: "paid-1", text: "paid copy", weight: 1, cpm: 10.0 }

      filtered = SponsoredLogs::Advertisers.drop_house([edited_house, paid])
      expect(filtered.map { |ad| ad[:id] }).to eq(["paid-1"])
      expect(filtered).not_to include(edited_house)
    end
  end
end
