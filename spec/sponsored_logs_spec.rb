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
  end

  describe "Advertisers" do
    it "provides exactly ten built-in ads" do
      expect(SponsoredLogs::Advertisers::DEFAULT_ADS.length).to eq(10)
    end

    it "defaults to an [AD] tagged line" do
      expect(SponsoredLogs::Advertisers.sample).to start_with("[AD] ")
    end

    it "accepts a custom prefix" do
      expect(SponsoredLogs::Advertisers.sample("YO:")).to start_with("YO: ")
    end

    it "samples from a supplied ad list" do
      expect(SponsoredLogs::Advertisers.sample("[AD]", [{ text: "Custom", weight: 1 }])).to eq("[AD] Custom")
    end

    it "falls back to defaults when the supplied list is empty", :aggregate_failures do
      expect(SponsoredLogs::Advertisers.sample("[AD]", [])).to start_with("[AD] ")
      expect(SponsoredLogs::Advertisers.sample("[AD]", [{ text: "", weight: 1 }])).to start_with("[AD] ")
    end

    it "falls back to defaults when every weight is zero" do
      zeroed = [{ text: "never", weight: 0 }]
      expect(SponsoredLogs::Advertisers.sample("[AD]", zeroed)).not_to include("never")
    end

    it "never picks a zero-weighted ad when others are available" do
      pool = [
        { text: "picked", weight: 1 },
        { text: "skipped", weight: 0 }
      ]
      results = Array.new(200) { SponsoredLogs::Advertisers.sample("", pool) }
      expect(results.uniq).to eq(["picked"])
    end

    it "honors relative weights", :aggregate_failures do
      pool = [
        { text: "common", weight: 9 },
        { text: "rare", weight: 1 }
      ]
      results = Array.new(3000) { SponsoredLogs::Advertisers.sample("", pool) }
      common = results.count("common")

      # Expect roughly 90% common; assert a wide band to stay non-flaky.
      expect(common).to be > 2400
      expect(common).to be < 2999
    end
  end

  describe "Advertisers.normalize" do
    it "defaults a missing weight to 1" do
      expect(SponsoredLogs::Advertisers.normalize([{ text: "x" }])).to eq([{ text: "x", weight: 1.0 }])
    end

    it "accepts string keys from parsed JSON" do
      expect(SponsoredLogs::Advertisers.normalize([{ "text" => "x", "weight" => 5 }])).to eq([{ text: "x", weight: 5.0 }])
    end

    it "clamps a negative weight to zero" do
      expect(SponsoredLogs::Advertisers.normalize([{ text: "x", weight: -3 }])).to eq([{ text: "x", weight: 0.0 }])
    end

    it "defaults an unparseable weight to 1" do
      expect(SponsoredLogs::Advertisers.normalize([{ text: "x", weight: "nope" }])).to eq([{ text: "x", weight: 1.0 }])
    end

    it "drops entries with blank text", :aggregate_failures do
      expect(SponsoredLogs::Advertisers.normalize([{ text: "  ", weight: 1 }])).to eq([])
      expect(SponsoredLogs::Advertisers.normalize(["a bare string"])).to eq([])
    end
  end
end
