RSpec.describe Issue do
  describe '#fetch_issues' do
    let!(:issue_tracker) { create(:issue_tracker) }
    let!(:issue) { create(:issue, issue_tracker: issue_tracker) }

    before do
      allow(IssueTracker).to receive(:find_by).and_return(issue_tracker)
      allow(issue_tracker).to receive(:fetch_issues)

      issue.fetch_issues
    end

    it 'fetches the issues' do
      expect(issue_tracker).to have_received(:fetch_issues)
    end
  end

  describe 'name_validation' do
    let(:issue_tracker) { create(:issue_tracker) }
    let(:issue_tracker_v1) { create(:issue_tracker, name: 'v1_tracker', regex: '([BD]-[\d]+)', label: '(B-@@@)') }
    let(:issue_tracker_cve) { IssueTracker.find_by(name: 'cve') } # Seeded in database. Regex: 'CVE-(\d\d\d\d-\d+)' label: 'CVE-@@@'

    let(:issue) { create(:issue, name: '1234', issue_tracker: issue_tracker) }
    let(:issue_v1) { create(:issue, name: '1234', issue_tracker: issue_tracker_v1) }
    let(:issue_cve_no_prefix) { build(:issue, name: '2019-12345', issue_tracker: issue_tracker_cve) }
    let(:issue_cve_uppercase) { build(:issue, name: 'CVE-2019-12345', issue_tracker: issue_tracker_cve) }
    let(:issue_cve_lowercase) { build(:issue, name: 'cve-2019-12345', issue_tracker: issue_tracker_cve) }

    it 'issue name should be valid' do
      expect(issue).to be_valid
    end

    it 'V1 style should be valid name' do
      expect(issue_v1).to be_valid
    end

    it 'CVE issue with pattern XXXX-YYYY should be valid name' do
      expect(issue_cve_no_prefix).to be_valid
    end

    # TODO: this pattern shouldn't be valid at creation time
    it 'CVE issue with pattern CVE-XXXX-YYYY should be valid name' do
      expect(issue_cve_uppercase).to be_valid
    end

    it 'cve-XXXX-YYYY should be an invalid name' do
      expect(issue_cve_lowercase).not_to be_valid
      expect(issue_cve_lowercase.errors.full_messages).to contain_exactly("Name with value '#{issue_cve_lowercase.name}' does not match defined regex #{issue_tracker_cve.regex}")
    end
  end
end
