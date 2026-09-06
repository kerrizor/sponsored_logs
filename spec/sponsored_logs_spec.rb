# frozen_string_literal: true

require "stringio"
require "logger"

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
  end

  describe "configuration" do
    it "defaults ad_prefix to [AD]" do
      expect(described_class.configuration.ad_prefix).to eq("[AD]")
    end
  end

  describe "Advertisers" do
    it "provides exactly ten ads" do
      expect(SponsoredLogs::Advertisers::ADS.length).to eq(10)
    end

    it "defaults to an [AD] tagged line" do
      expect(SponsoredLogs::Advertisers.sample).to start_with("[AD] ")
    end

    it "accepts a custom prefix" do
      expect(SponsoredLogs::Advertisers.sample("YO:")).to start_with("YO: ")
    end
  end
end
