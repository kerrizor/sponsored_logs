# frozen_string_literal: true

RSpec.describe SponsoredLogs::Ledger do
  let(:ledger) { described_class.new(SponsoredLogs::Storage::Memory.new) }

  it "counts impressions per ad text" do
    3.times { ledger.record(text: "a", weight: 1, cpm: 10.0) }
    2.times { ledger.record(text: "b", weight: 1, cpm: 0.0) }

    expect(ledger.total_impressions).to eq(5)
  end

  it "computes spend as impressions / 1000 * cpm" do
    500.times { ledger.record(text: "a", weight: 1, cpm: 20.0) }

    # 500 / 1000 * 20 = 10.0
    expect(ledger.total_spend).to be_within(0.0001).of(10.0)
  end

  it "sums spend across ads", :aggregate_failures do
    1000.times { ledger.record(text: "a", weight: 1, cpm: 20.0) } # $20
    1000.times { ledger.record(text: "b", weight: 1, cpm: 5.0) }  # $5

    expect(ledger.total_spend).to be_within(0.0001).of(25.0)
    expect(ledger.entries.length).to eq(2)
  end

  it "exposes per-ad entries", :aggregate_failures do
    100.times { ledger.record(text: "a", weight: 1, cpm: 30.0) }
    entry = ledger.entries.first

    expect(entry.text).to eq("a")
    expect(entry.impressions).to eq(100)
    expect(entry.cpm).to eq(30.0)
    expect(entry.spend).to be_within(0.0001).of(3.0)
  end

  it "reset clears all tallies", :aggregate_failures do
    ledger.record(text: "a", weight: 1, cpm: 10.0)
    ledger.reset

    expect(ledger.total_impressions).to eq(0)
    expect(ledger.total_spend).to eq(0.0)
    expect(ledger.entries).to eq([])
  end
end
