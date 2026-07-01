require "rails_helper"

RSpec.describe WebhookUrlGuard do
  def stub_dns(host, *ips)
    allow(Resolv).to receive(:getaddresses).with(host).and_return(ips)
  end

  it "allows a public https url" do
    stub_dns("api.customer-example.com", "203.0.113.10")
    expect(described_class.safe?("https://api.customer-example.com/hooks")).to be true
  end

  it "rejects plain http" do
    expect(described_class.safe?("http://api.customer-example.com/hooks")).to be false
  end

  it "rejects the cloud metadata address explicitly" do
    expect(described_class.safe?("https://169.254.169.254/latest/meta-data/")).to be false
  end

  it "rejects a hostname that resolves to a private/internal address (SSRF via DNS)" do
    stub_dns("internal.attacker-controlled.com", "10.0.0.5")
    expect(described_class.safe?("https://internal.attacker-controlled.com/hooks")).to be false
  end

  it "rejects a hostname that resolves to loopback" do
    stub_dns("attacker-controlled.com", "127.0.0.1")
    expect(described_class.safe?("https://attacker-controlled.com/hooks")).to be false
  end

  it "rejects if ANY resolved address is private, even if another is public (multi-A-record rebinding)" do
    stub_dns("attacker-controlled.com", "203.0.113.10", "169.254.169.254")
    expect(described_class.safe?("https://attacker-controlled.com/hooks")).to be false
  end

  it "rejects an unparseable url" do
    expect(described_class.safe?("not a url")).to be false
  end

  it "rejects a blank host" do
    expect(described_class.safe?("https:///path")).to be false
  end
end
