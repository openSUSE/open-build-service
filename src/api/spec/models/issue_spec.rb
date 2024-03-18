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

  describe 'validate' do
    let!(:issue_tracker) { create(:issue_tracker) }
    let!(:issue_tracker_v1) { create(:issue_tracker, name: 'v1_tracker', regex: '([BD]-[\d]+)', label: '(B-@@@)') }
    let!(:issue_tracker_cve) { create(:issue_tracker, name: 'cve_tracker', regex: '^(?:cve|CVE)-(\d\d\d\d-\d+)', label: 'CVE-@@@') }

    let!(:issue) { create(:issue, name: '1234', issue_tracker: issue_tracker) }
    let!(:issue_v1) { create(:issue, name: '1234', issue_tracker: issue_tracker_v1) }
    let!(:issue_cve) { build(:issue, name: 'CVE-2019-12345', issue_tracker: issue_tracker_cve) }

    it 'issue name should be valid' do
      expect(issue).to be_valid
    end

    it 'V1 style should be valid name' do
      expect(issue_v1).to be_valid
    end

    it 'CVE-XXXX-YYYY should be an invalid name' do
      expect { issue_cve.save! }.to raise_error(ActiveRecord::RecordInvalid, /does not match defined regex/)
    end
  end
end
