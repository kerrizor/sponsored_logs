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
    it "reads the ads array from a well-formed file" do
      with_file('{"ads": ["one", "two"]}') do |path|
        expect(described_class.load(path, warn_to: sink)).to eq(%w[one two])
      end
    end

    it "strips blank entries" do
      with_file('{"ads": ["kept", "", "  "]}') do |path|
        expect(described_class.load(path, warn_to: sink)).to eq(["kept"])
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
