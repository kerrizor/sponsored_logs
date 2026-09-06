# frozen_string_literal: true

require "tempfile"

RSpec.describe SponsoredLogs::AdsFile do
  def with_file(contents)
    Tempfile.create(["ads", ".json"]) do |f|
      f.write(contents)
      f.flush
      yield f.path
    end
  end

  let(:sink) { StringIO.new }

  describe ".load" do
    it "reads weighted ads with cpm from a well-formed file", :aggregate_failures do
      with_file('{"ads": [{"text": "one", "weight": 3, "cpm": 20}, {"text": "two", "weight": 1}]}') do |path|
        loaded = described_class.load(path, warn_to: sink)
        expect(loaded.map { |a| a.slice(:text, :weight, :cpm) }).to eq(
          [{ text: "one", weight: 3.0, cpm: 20.0 }, { text: "two", weight: 1.0, cpm: 0.0 }]
        )
      end
    end

    it "defaults a missing weight to 1 and cpm to 0" do
      with_file('{"ads": [{"text": "one"}]}') do |path|
        expect(described_class.load(path, warn_to: sink).first)
          .to include(text: "one", weight: 1.0, cpm: 0.0)
      end
    end

    it "reads flight bounds from a file", :aggregate_failures do
      with_file('{"ads": [{"text": "flighted", "starts_at": "2026-01-01T00:00:00Z", "ends_at": "2026-12-31T00:00:00Z"}]}') do |path|
        ad = described_class.load(path, warn_to: sink).first
        expect(ad[:starts_at]).to be_a(Time)
        expect(ad[:ends_at]).to be_a(Time)
      end
    end

    it "drops entries with blank text" do
      with_file('{"ads": [{"text": "kept", "weight": 1}, {"text": "  "}]}') do |path|
        loaded = described_class.load(path, warn_to: sink)
        expect(loaded.map { |a| a[:text] }).to eq(["kept"])
      end
    end

    it "returns nil and warns for a bare array", :aggregate_failures do
      with_file('["one", "two"]') do |path|
        expect(described_class.load(path, warn_to: sink)).to be_nil
        expect(sink.string).to include("expected an object")
      end
    end

    it "returns nil and warns when the ads key is missing", :aggregate_failures do
      with_file('{"messages": ["one"]}') do |path|
        expect(described_class.load(path, warn_to: sink)).to be_nil
        expect(sink.string).to include("expected an object")
      end
    end

    it "returns nil and warns on invalid JSON", :aggregate_failures do
      with_file("{not valid json") do |path|
        expect(described_class.load(path, warn_to: sink)).to be_nil
        expect(sink.string).to include("invalid JSON")
      end
    end

    it "returns nil and warns when the file is missing", :aggregate_failures do
      expect(described_class.load("/no/such/ads.json", warn_to: sink)).to be_nil
      expect(sink.string).to include("not found")
    end
  end
end
