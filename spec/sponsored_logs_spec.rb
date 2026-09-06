# frozen_string_literal: true

require "stringio"
require "logger"
require "tempfile"

RSpec.describe SponsoredLogs do
  describe ".sponsor! and .unsponsor!" do
    it "toggles the active flag", :aggregate_failures do
      expect(described_class.active?).to be(false)

      described_class.sponsor!
      expect(described_class.active?).to be(true)

      described_class.unsponsor!
      expect(described_class.active?).to be(false)
    end

    it "installs the injector patches on first sponsor" do
      described_class.sponsor!
      expect(SponsoredLogs::Injector).to be_installed
    end

    it "applies inline configuration overrides", :aggregate_failures do
      described_class.sponsor!(probability: 0.5, interval: 7)

      expect(described_class.configuration.probability).to eq(0.5)
      expect(described_class.configuration.interval).to eq(7)
    end

    it "accepts an explicit options hash", :aggregate_failures do
      described_class.sponsor!({ probability: 0.25, ad_prefix: "YO:" })

      expect(described_class.configuration.probability).to eq(0.25)
      expect(described_class.configuration.ad_prefix).to eq("YO:")
    end
  end

  describe "Configuration#assign" do
    let(:config) { SponsoredLogs::Configuration.new }
    let(:sink) { StringIO.new }

    it "applies direct settings", :aggregate_failures do
      config.assign({ probability: 0.4, selection: :cpm }, warn_to: sink)

      expect(config.probability).to eq(0.4)
      expect(config.selection).to eq(:cpm)
    end

    it "accepts string keys" do
      config.assign({ "probability" => 0.6 }, warn_to: sink)
      expect(config.probability).to eq(0.6)
    end

    it "leaves unspecified settings untouched", :aggregate_failures do
      config.assign({ probability: 0.9 }, warn_to: sink)

      expect(config.probability).to eq(0.9)
      expect(config.ad_prefix).to eq("[AD]") # default preserved
    end

    it "warns on an unknown key rather than raising", :aggregate_failures do
      expect { config.assign({ bogus: 1 }, warn_to: sink) }.not_to raise_error
      expect(sink.string).to include("unknown setting")
      expect(sink.string).to include("bogus")
    end

    it "resolves ads_file into ads" do
      Tempfile.create(["ads", ".json"]) do |f|
        f.write('{"ads": [{"text": "FromFile", "weight": 1}]}')
        f.flush
        config.assign({ ads_file: f.path }, warn_to: sink)
      end

      expect(config.ads.first).to include(text: "FromFile", weight: 1.0, cpm: 0.0)
    end

    it "prefers an explicit ads list over ads_file" do
      config.assign({ ads: [{ text: "Inline", weight: 1 }], ads_file: "/no/such.json" }, warn_to: sink)

      expect(config.ads).to eq([{ text: "Inline", weight: 1 }])
    end
  end

  describe ".maybe_emit" do
    it "does nothing when inactive" do
      io = StringIO.new
      described_class.maybe_emit(target: io)
      expect(io.string).to be_empty
    end

    it "emits when active and the dice land in range" do
      io = StringIO.new
      described_class.sponsor!(probability: 1.0)

      described_class.maybe_emit(target: io)
      expect(io.string).to include("[AD]")
    end

    it "stays silent when probability is zero" do
      io = StringIO.new
      described_class.sponsor!(probability: 0.0)

      100.times { described_class.maybe_emit(target: io) }
      expect(io.string).to be_empty
    end
  end

  describe ".emit" do
    it "writes a tagged ad line to an IO target" do
      io = StringIO.new
      described_class.emit(io)
      expect(io.string).to match(/\A\[AD\] .+\n\z/)
    end

    it "returns the emitted line" do
      io = StringIO.new
      expect(described_class.emit(io)).to start_with("[AD]")
    end

    it "honors a custom ad_prefix" do
      io = StringIO.new
      described_class.sponsor!(ad_prefix: "SPONSORED:")
      described_class.emit(io)
      expect(io.string).to start_with("SPONSORED: ")
    end

    it "omits the prefix entirely when blank" do
      io = StringIO.new
      described_class.sponsor!(ad_prefix: "")
      described_class.emit(io)
      expect(io.string).not_to include("[AD]")
    end

    it "emits from a user-supplied ad list" do
      io = StringIO.new
      described_class.sponsor!(ads: [{ text: "Only ad in the pool", weight: 1 }])
      described_class.emit(io)
      expect(io.string).to eq("[AD] Only ad in the pool\n")
    end

    it "emits from an ads_file" do
      io = StringIO.new
      Tempfile.create(["ads", ".json"]) do |f|
        f.write('{"ads": [{"text": "From a file", "weight": 1}]}')
        f.flush
        described_class.sponsor!(ads_file: f.path)
      end
      described_class.emit(io)
      expect(io.string).to eq("[AD] From a file\n")
    end

    it "keeps the existing list when an ads_file fails to load" do
      io = StringIO.new
      described_class.sponsor!(ads: [{ text: "still here", weight: 1 }])
      described_class.sponsor!(ads_file: "/no/such.json") # warns, no-op on the list
      described_class.emit(io)
      expect(io.string).to eq("[AD] still here\n")
    end
  end

  describe "configuration" do
    it "defaults ad_prefix to [AD]" do
      expect(described_class.configuration.ad_prefix).to eq("[AD]")
    end

    it "defaults ads to the built-in list" do
      expect(described_class.configuration.ads).to eq(SponsoredLogs::Advertisers::DEFAULT_ADS)
    end

    it "defaults selection to :weight" do
      expect(described_class.configuration.selection).to eq(:weight)
    end
  end

  describe ".report" do
    it "starts empty", :aggregate_failures do
      described_class.reset_ledger!
      report = described_class.report

      expect(report[:impressions]).to eq(0)
      expect(report[:spend]).to eq(0.0)
      expect(report[:ads]).to eq([])
    end

    it "tallies impressions and accrues cpm-based spend", :aggregate_failures do
      described_class.reset_ledger!
      described_class.sponsor!(ads: [{ text: "Solo", weight: 1, cpm: 20.0 }])

      1000.times { described_class.emit(StringIO.new) }
      report = described_class.report

      expect(report[:impressions]).to eq(1000)
      # 1000 impressions / 1000 * $20 CPM = $20.00
      expect(report[:spend]).to be_within(0.0001).of(20.0)
      expect(report[:ads].first).to include(text: "Solo", impressions: 1000, cpm: 20.0)
      expect(report[:ads].first[:spend]).to be_within(0.0001).of(20.0)
    end

    it "reset_ledger! clears accrued totals" do
      described_class.sponsor!(ads: [{ text: "x", weight: 1, cpm: 5 }])
      described_class.emit(StringIO.new)
      described_class.reset_ledger!

      expect(described_class.report[:impressions]).to eq(0)
    end

    it "enriches rows with flight window and status", :aggregate_failures do
      described_class.reset_ledger!
      described_class.sponsor!(ads: [
        { text: "Evergreen", weight: 1, cpm: 5 },
        { text: "Ended", weight: 1, cpm: 5, ends_at: "2000-01-01" }
      ])
      # Force both to record regardless of liveness by writing to the store.
      described_class.configuration.store.record(text: "Evergreen", weight: 1, cpm: 5.0)
      described_class.configuration.store.record(text: "Ended", weight: 1, cpm: 5.0)

      rows = described_class.report[:ads].each_with_object({}) { |ad, h| h[ad[:text]] = ad }

      expect(rows["Evergreen"][:status]).to eq(:evergreen)
      expect(rows["Evergreen"][:starts_at]).to be_nil
      expect(rows["Ended"][:status]).to eq(:ended)
      expect(rows["Ended"][:ends_at]).to be_a(Time)
    end

    it "rounds spend to cents", :aggregate_failures do
      described_class.reset_ledger!
      # 333 / 1000 * 13 = 4.329 -> rounds to 4.33
      described_class.sponsor!(ads: [{ text: "odd", weight: 1, cpm: 13.0 }])
      333.times { described_class.emit(StringIO.new) }
      report = described_class.report

      expect(report[:spend]).to eq(4.33)
      expect(report[:ads].first[:spend]).to eq(4.33)
    end
  end

  describe ".report_text" do
    it "renders a table with a header, rows, and a total", :aggregate_failures do
      described_class.reset_ledger!
      described_class.sponsor!(ads: [{ text: "Solo", weight: 1, cpm: 20.0 }])
      100.times { described_class.emit(StringIO.new) }

      text = described_class.report_text

      expect(text).to include("Ad")
      expect(text).to include("Impr")
      expect(text).to include("CPM")
      expect(text).to include("Spend")
      expect(text).to include("Solo")
      expect(text).to match(/TOTAL\s+100\s+2\.00/) # 100/1000 * 20 = 2.00
    end

    it "orders rows by descending spend" do
      described_class.reset_ledger!
      described_class.sponsor!(ads: [
        { text: "cheap", weight: 1, cpm: 1.0 },
        { text: "pricey", weight: 1, cpm: 99.0 }
      ], selection: :cpm)
      1000.times { described_class.emit(StringIO.new) }

      text = described_class.report_text
      expect(text.index("pricey")).to be < text.index("cheap")
    end
  end

  describe "Advertisers" do
    it "provides exactly ten built-in ads" do
      expect(SponsoredLogs::Advertisers::DEFAULT_ADS.length).to eq(10)
    end

    def render(ads = nil, prefix: "[AD]", mode: :weight)
      if ads
        SponsoredLogs::Advertisers.render(SponsoredLogs::Advertisers.pick(ads, mode: mode), prefix)
      else
        SponsoredLogs::Advertisers.render(SponsoredLogs::Advertisers.pick, prefix)
      end
    end

    it "defaults to an [AD] tagged line" do
      expect(render).to start_with("[AD] ")
    end

    it "accepts a custom prefix" do
      expect(render(prefix: "YO:")).to start_with("YO: ")
    end

    it "samples from a supplied ad list" do
      expect(render([{ text: "Custom", weight: 1 }])).to eq("[AD] Custom")
    end

    it "falls back to defaults when the supplied list is empty", :aggregate_failures do
      expect(render([])).to start_with("[AD] ")
      expect(render([{ text: "", weight: 1 }])).to start_with("[AD] ")
    end

    it "falls back to defaults when every weight is zero" do
      zeroed = [{ text: "never", weight: 0 }]
      expect(render(zeroed)).not_to include("never")
    end

    it "never picks a zero-weighted ad when others are available" do
      pool = [
        { text: "picked", weight: 1 },
        { text: "skipped", weight: 0 }
      ]
      results = Array.new(200) { render(pool, prefix: "") }
      expect(results.uniq).to eq(["picked"])
    end

    it "honors relative weights", :aggregate_failures do
      pool = [
        { text: "common", weight: 9 },
        { text: "rare", weight: 1 }
      ]
      results = Array.new(3000) { render(pool, prefix: "") }
      common = results.count("common")

      # Expect roughly 90% common; assert a wide band to stay non-flaky.
      expect(common).to be > 2400
      expect(common).to be < 2999
    end

    it "picks by cpm in :cpm selection mode", :aggregate_failures do
      pool = [
        { text: "pricey", weight: 1, cpm: 90 },
        { text: "cheap", weight: 1, cpm: 10 }
      ]
      results = Array.new(3000) { render(pool, prefix: "", mode: :cpm) }
      pricey = results.count("pricey")

      expect(pricey).to be > 2400
      expect(pricey).to be < 2999
    end

    it "ignores cpm when in :weight mode" do
      pool = [
        { text: "high cpm low weight", weight: 0, cpm: 99 },
        { text: "picked", weight: 1, cpm: 1 }
      ]
      results = Array.new(200) { render(pool, prefix: "", mode: :weight) }
      expect(results.uniq).to eq(["picked"])
    end

    it "falls back to weights when :cpm mode has all-zero cpm" do
      pool = [
        { text: "picked", weight: 1, cpm: 0 },
        { text: "skipped", weight: 0, cpm: 0 }
      ]
      results = Array.new(200) { render(pool, prefix: "", mode: :cpm) }
      expect(results.uniq).to eq(["picked"])
    end
  end

  describe "Advertisers.normalize" do
    it "defaults weight to 1 and cpm to 0" do
      expect(SponsoredLogs::Advertisers.normalize([{ text: "x" }]).first)
        .to include(text: "x", weight: 1.0, cpm: 0.0)
    end

    it "accepts string keys from parsed JSON" do
      expect(SponsoredLogs::Advertisers.normalize([{ "text" => "x", "weight" => 5, "cpm" => 12 }]).first)
        .to include(text: "x", weight: 5.0, cpm: 12.0)
    end

    it "clamps a negative weight to zero" do
      expect(SponsoredLogs::Advertisers.normalize([{ text: "x", weight: -3 }]).first)
        .to include(weight: 0.0)
    end

    it "defaults an unparseable weight to 1 and unparseable cpm to 0" do
      expect(SponsoredLogs::Advertisers.normalize([{ text: "x", weight: "nope", cpm: "bad" }]).first)
        .to include(weight: 1.0, cpm: 0.0)
    end

    it "drops entries with blank text", :aggregate_failures do
      expect(SponsoredLogs::Advertisers.normalize([{ text: "  ", weight: 1 }])).to eq([])
      expect(SponsoredLogs::Advertisers.normalize(["a bare string"])).to eq([])
    end

    it "defaults flight bounds to nil", :aggregate_failures do
      ad = SponsoredLogs::Advertisers.normalize([{ text: "x" }]).first
      expect(ad[:starts_at]).to be_nil
      expect(ad[:ends_at]).to be_nil
    end

    it "parses string flight bounds into Time", :aggregate_failures do
      ad = SponsoredLogs::Advertisers.normalize(
        [{ text: "x", starts_at: "2026-01-01T00:00:00Z", ends_at: "2026-12-31T23:59:59Z" }]
      ).first
      expect(ad[:starts_at]).to be_a(Time)
      expect(ad[:ends_at]).to be_a(Time)
      expect(ad[:starts_at].year).to eq(2026)
    end

    it "accepts Time objects directly" do
      t = Time.now
      ad = SponsoredLogs::Advertisers.normalize([{ text: "x", starts_at: t }]).first
      expect(ad[:starts_at]).to be_within(1).of(t)
    end

    it "turns an unparseable flight bound into nil" do
      ad = SponsoredLogs::Advertisers.normalize([{ text: "x", starts_at: "not a date" }]).first
      expect(ad[:starts_at]).to be_nil
    end
  end

  describe "Advertisers flighting" do
    let(:now) { Time.utc(2026, 6, 15, 12, 0, 0) }

    def pick_text(ads, **opts)
      SponsoredLogs::Advertisers.render(SponsoredLogs::Advertisers.pick(ads, **opts), "")
    end

    it "excludes ads whose window has not started" do
      ads = [{ text: "future", weight: 1, starts_at: "2026-07-01T00:00:00Z" }]
      # Only live pool member is gone -> falls back to defaults, never "future".
      results = Array.new(50) { pick_text(ads, now: now) }
      expect(results).not_to include("future")
    end

    it "excludes ads whose window has ended" do
      ads = [{ text: "expired", weight: 1, ends_at: "2026-01-01T00:00:00Z" }]
      results = Array.new(50) { pick_text(ads, now: now) }
      expect(results).not_to include("expired")
    end

    it "includes ads inside their window" do
      ads = [
        { text: "live", weight: 1, starts_at: "2026-06-01T00:00:00Z", ends_at: "2026-07-01T00:00:00Z" }
      ]
      expect(pick_text(ads, now: now)).to eq("live")
    end

    it "treats missing bounds as open-ended", :aggregate_failures do
      expect(SponsoredLogs::Advertisers.live?({ starts_at: nil, ends_at: nil }, now)).to be(true)
    end

    it "picks only the live ad from a mixed pool" do
      ads = [
        { text: "live", weight: 1 },
        { text: "expired", weight: 1, ends_at: "2026-01-01T00:00:00Z" }
      ]
      results = Array.new(100) { pick_text(ads, now: now) }
      expect(results.uniq).to eq(["live"])
    end

    describe ".status" do
      it "is :evergreen with no bounds" do
        expect(SponsoredLogs::Advertisers.status({ starts_at: nil, ends_at: nil }, now)).to eq(:evergreen)
      end

      it "is :scheduled before the window" do
        ad = { starts_at: Time.utc(2026, 8, 1), ends_at: nil }
        expect(SponsoredLogs::Advertisers.status(ad, now)).to eq(:scheduled)
      end

      it "is :ended after the window" do
        ad = { starts_at: nil, ends_at: Time.utc(2026, 1, 1) }
        expect(SponsoredLogs::Advertisers.status(ad, now)).to eq(:ended)
      end

      it "is :active inside the window" do
        ad = { starts_at: Time.utc(2026, 6, 1), ends_at: Time.utc(2026, 7, 1) }
        expect(SponsoredLogs::Advertisers.status(ad, now)).to eq(:active)
      end
    end
  end
end
