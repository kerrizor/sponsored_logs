# frozen_string_literal: true

require "active_record"
require "tmpdir"

RSpec.describe SponsoredLogs::Ledger::Store::ActiveRecord do
  before(:all) do
    # A file-backed SQLite db (not :memory:) so every connection in the pool --
    # including ones opened by other threads -- sees the same table.
    #
    @db_path = File.join(Dir.mktmpdir, "sponsored_logs_test.sqlite3")
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: @db_path)
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table :sponsored_logs_impressions, force: true do |t|
        t.string  :text_digest, null: false
        t.text    :text,        null: false
        t.integer :impressions, null: false, default: 0
        t.float   :cpm,         null: false, default: 0.0
        t.timestamps
      end
      add_index :sponsored_logs_impressions, :text_digest, unique: true
    end
  end

  after(:all) do
    ActiveRecord::Base.remove_connection
    FileUtils.rm_f(@db_path)
  end

  let(:store) { described_class.new }

  after { store.reset }

  it "records impressions and cpm, keyed by text" do
    2.times { store.record(text: "a", weight: 1, cpm: 10.0) }
    store.record(text: "b", weight: 1, cpm: 5.0)

    expect(store.snapshot).to eq(
      "a" => { impressions: 2, cpm: 10.0 },
      "b" => { impressions: 1, cpm: 5.0 }
    )
  end

  it "persists across store instances (same table)", :aggregate_failures do
    described_class.new.record(text: "persisted", weight: 1, cpm: 7.0)

    fresh = described_class.new
    expect(fresh.snapshot["persisted"]).to eq(impressions: 1, cpm: 7.0)
  end

  it "increments atomically under concurrency" do
    threads = Array.new(5) do
      Thread.new { 20.times { described_class.new.record(text: "hot", weight: 1, cpm: 1.0) } }
    end
    threads.each(&:join)

    expect(store.snapshot["hot"][:impressions]).to eq(100)
  end

  it "reset clears the rows" do
    store.record(text: "a", weight: 1, cpm: 10.0)
    store.reset
    expect(store.snapshot).to eq({})
  end

  it "handles long ad text via the digest key" do
    long = "Sponsored by " + ("x" * 5000)
    store.record(text: long, weight: 1, cpm: 3.0)

    expect(store.snapshot[long]).to eq(impressions: 1, cpm: 3.0)
  end
end
