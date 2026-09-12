# frozen_string_literal: true

require "stringio"

RSpec.describe SponsoredLogs do
  describe "html_probability configuration" do
    it "defaults to 0.05" do
      expect(described_class.configuration.html_probability).to eq(0.05)
    end

    it "is applied via sponsor!/assign", :aggregate_failures do
      described_class.sponsor!(html_probability: 0.5)

      expect(described_class.configuration.html_probability).to eq(0.5)
    end

    it "accepts string keys through assign" do
      config = SponsoredLogs::Configuration.new
      config.assign({ "html_probability" => 0.6 }, warn_to: StringIO.new)

      expect(config.html_probability).to eq(0.6)
    end

    it "is separate from probability", :aggregate_failures do
      described_class.sponsor!(probability: 0.2, html_probability: 0.9)

      expect(described_class.configuration.probability).to eq(0.2)
      expect(described_class.configuration.html_probability).to eq(0.9)
    end
  end

  describe ".render_html_comment" do
    it "wraps the picked ad text as an HTML comment", :aggregate_failures do
      described_class.sponsor!(ads: [{ text: "Buy widgets now", weight: 1 }])

      comment = described_class.render_html_comment

      expect(comment).to start_with("<!-- [AD] ")
      expect(comment).to end_with(" -->")
      expect(comment).to include("Buy widgets now")
    end

    it "uses the configured ad_prefix" do
      described_class.sponsor!(ad_prefix: "SPONSORED:", ads: [{ text: "Copy here", weight: 1 }])

      expect(described_class.render_html_comment).to eq("<!-- SPONSORED: Copy here -->")
    end

    it "records the impression to the ledger", :aggregate_failures do
      described_class.sponsor!(ads: [{ text: "Track me", weight: 1, cpm: 10.0 }])

      expect { described_class.render_html_comment }
        .to change { described_class.ledger.total_impressions }.by(1)
    end

    it "returns nil when no ad can be picked" do
      described_class.sponsor!
      allow(SponsoredLogs::Advertisers).to receive(:pick).and_return(nil)

      expect(described_class.render_html_comment).to be_nil
    end

    it "does not record when no ad can be picked" do
      described_class.sponsor!
      allow(SponsoredLogs::Advertisers).to receive(:pick).and_return(nil)

      expect { described_class.render_html_comment }
        .not_to(change { described_class.ledger.total_impressions })
    end

    it "carries no ANSI color codes" do
      described_class.sponsor!(ads: [{ text: "Plain text ad", weight: 1 }])

      expect(described_class.render_html_comment).not_to match(/\e\[/)
    end
  end

  describe ".render_html_comment delimiter hardening" do
    it "neutralizes a closing comment delimiter in ad copy", :aggregate_failures do
      described_class.sponsor!(ads: [{ text: "Legit --> <script>alert(1)</script>", weight: 1 }])

      comment = described_class.render_html_comment

      # The only closer is the real trailing one; the injected --> is broken.
      #
      expect(comment.scan("-->").length).to eq(1)
      expect(comment).to end_with(" -->")
      expect(comment).not_to include("--> <script>")
    end

    it "neutralizes bare double-hyphen sequences inside the comment" do
      described_class.sponsor!(ads: [{ text: "a -- b -- c", weight: 1 }])

      comment = described_class.render_html_comment
      body = comment.delete_prefix("<!-- ").delete_suffix(" -->")

      expect(body).not_to include("--")
    end

    it "still ends with exactly one valid closer for adversarial copy", :aggregate_failures do
      described_class.sponsor!(ads: [{ text: "--> --> -->", weight: 1 }])

      comment = described_class.render_html_comment

      expect(comment.scan("-->").length).to eq(1)
      expect(comment).to start_with("<!-- [AD] ")
      expect(comment).to end_with(" -->")
    end
  end

  describe SponsoredLogs::HtmlComment do
    describe ".escape" do
      it "leaves copy without hyphen runs untouched" do
        expect(described_class.escape("plain copy")).to eq("plain copy")
      end

      it "breaks up every double-hyphen run", :aggregate_failures do
        result = described_class.escape("a--b-->c")

        expect(result).not_to include("--")
        expect(result).not_to include("-->")
      end
    end
  end

  describe ".maybe_html_comment" do
    it "returns nil when sponsoring is inactive" do
      described_class.unsponsor!

      expect(described_class.maybe_html_comment).to be_nil
    end

    it "emits when active and probability is 1.0", :aggregate_failures do
      described_class.sponsor!(html_probability: 1.0, ads: [{ text: "Always on", weight: 1 }])

      comment = described_class.maybe_html_comment

      expect(comment).to include("Always on")
      expect(comment).to start_with("<!-- ")
    end

    it "stays silent when html_probability is zero" do
      described_class.sponsor!(html_probability: 0.0, ads: [{ text: "Never", weight: 1 }])

      results = Array.new(100) { described_class.maybe_html_comment }

      expect(results.compact).to be_empty
    end

    it "does not consult probability when inactive" do
      described_class.unsponsor!
      described_class.configuration.html_probability = 1.0

      expect(described_class.maybe_html_comment).to be_nil
    end
  end
end
