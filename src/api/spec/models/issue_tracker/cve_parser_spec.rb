RSpec.describe IssueTracker::CVEParser, :vcr do
  let(:issue_tracker) { create(:issue_tracker) }
  let(:cve_parser) { IssueTracker::CVEParser.new }

  describe '.new' do
    it { expect(IssueTracker::CVEParser.new).not_to be_nil }
  end

  describe 'tracker=' do
    it { expect(cve_parser.tracker = issue_tracker).not_to be_nil }
  end

  describe '#start_element' do
    before do
      allow(IssueTracker).to receive(:find_by).and_return(issue_tracker)
      cve_parser.tracker = issue_tracker
    end

    it { expect(cve_parser.start_element('item', [%w[name CVE-2010-31337]])).to be_falsey }
  end

  describe '#cve' do
    it { expect(cve_parser.cve([%w[name CVE-2010-31337]])).not_to be_nil }
    it { expect(cve_parser.cve([%w[xxxx CVE-2010-31337]])).to be_nil }
  end

  describe '#my_issue_and_desc_name' do
    before do
      allow(IssueTracker).to receive(:find_by).and_return(issue_tracker)
      cve_parser.tracker = issue_tracker
      cve_parser.start_element('item', [%w[name CVE-2010-31337]])
    end

    it { expect(cve_parser.my_issue_and_desc_name('desc')).to be_truthy }
    it { expect(cve_parser.my_issue_and_desc_name('xxxx')).to be_falsey }
  end

  describe 'read a complete XML' do
    let(:xml) do
      <<~XML
        <item type="CVE" name="CVE-1999-0002" seq="1999-0002">
          <status>Entry</status>
          <desc>Buffer overflow in NFS mountd gives root access to remote attackers, mostly in Linux systems.</desc>
          <refs>
            <ref source="SGI" url="ftp://patches.sgi.com/support/free/security/advisories/19981006-01-I">19981006-01-I</ref>
            <ref source="CERT">CA-98.12.mountd</ref>
            <ref source="CIAC" url="http://www.ciac.org/ciac/bulletins/j-006.shtml">J-006</ref>
            <ref source="BID" url="http://www.securityfocus.com/bid/121">121</ref>
            <ref source="XF">linux-mountd-bo</ref>
          </refs>
        </item>
      XML
    end

    let(:parser) { Nokogiri::XML::SAX::Parser.new(cve_parser) }

    before do
      allow(IssueTracker).to receive(:find_by).and_return(issue_tracker)
      cve_parser.tracker = issue_tracker
    end

    it { expect { parser.parse(xml) }.not_to raise_error }
  end
end
