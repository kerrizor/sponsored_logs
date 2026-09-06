# frozen_string_literal: true

RSpec.describe SponsoredLogs::Ledger::Store::Base do
  it "raises NotImplementedError for the contract methods", :aggregate_failures do
    base = described_class.new
    expect { base.record({}) }.to raise_error(NotImplementedError)
    expect { base.snapshot }.to raise_error(NotImplementedError)
    expect { base.reset }.to raise_error(NotImplementedError)
  end
end

RSpec.describe SponsoredLogs::Ledger::Store::Memory do
  let(:store) { described_class.new }

  it "records impressions and cpm, keyed by text" do
    2.times { store.record(text: "a", weight: 1, cpm: 10.0) }
    store.record(text: "b", weight: 1, cpm: 5.0)

    expect(store.snapshot).to eq(
      "a" => { impressions: 2, cpm: 10.0 },
      "b" => { impressions: 1, cpm: 5.0 }
    )
  end

  it "reset clears the snapshot" do
    store.record(text: "a", weight: 1, cpm: 10.0)
    store.reset
    expect(store.snapshot).to eq({})
  end

  it "records concurrently without losing increments" do
    threads = Array.new(10) do
      Thread.new { 100.times { store.record(text: "a", weight: 1, cpm: 1.0) } }
    end
    threads.each(&:join)

    expect(store.snapshot["a"][:impressions]).to eq(1000)
  end
end

RSpec.describe SponsoredLogs::Ledger::Store::Redis do
  # Minimal in-memory stand-in for the redis client, exercising the exact
  # commands the adapter uses (hincrby/hset/hgetall/del).
  #
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

  it "records impressions and cpm via the client" do
    2.times { store.record(text: "a", weight: 1, cpm: 10.0) }
    store.record(text: "b", weight: 1, cpm: 5.0)

    expect(store.snapshot).to eq(
      "a" => { impressions: 2, cpm: 10.0 },
      "b" => { impressions: 1, cpm: 5.0 }
    )
  end

  it "reset deletes the keys" do
    store.record(text: "a", weight: 1, cpm: 10.0)
    store.reset
    expect(store.snapshot).to eq({})
  end
end
