require 'rails_helper'

RSpec.describe MaintenanceStatistic do
  describe '.find_by_project' do
    let(:user) { create(:confirmed_user) }
    let!(:project) do
      create(
        :project_with_repository,
        name: 'ProjectWithRepo',
        created_at: 10.days.ago
      )
    end
    let!(:bs_request) do
      create(
        :bs_request,
        source_project: project,
        type: 'maintenance_release',
        created_at: 9.days.ago
      )
    end
    let!(:history_element_request_created) do
      create(
        :history_element_request_created,
        request: bs_request,
        user: user,
        created_at: 8.days.ago
      )
    end
    let!(:history_element_request_accepted) do
      create(
        :history_element_request_accepted,
        request: bs_request,
        user: user,
        created_at: 7.days.ago
      )
    end
    let!(:review) do
      create(
        :review,
        bs_request: bs_request,
        by_user: user.login,
        created_at: 6.days.ago,
        updated_at: 5.days.ago,
        state: :accepted
      )
    end
    let(:package) { create(:package_with_file, project: project) }
    let!(:issue_tracker) { create(:issue_tracker) }
    let!(:issue) { create(:issue, issue_tracker_id: issue_tracker.id, created_at: 4.days.ago) }
    let!(:package_issue) { create(:package_issue, package: package, issue: issue) }

    subject(:maintenance_statistics) { MaintenanceStatistic.find_by_project(project) }

    it 'contains issue_created' do
      expect(maintenance_statistics[0].type).to eq(:issue_created)
      expect(maintenance_statistics[0].when).to eq(issue.created_at)
    end

    it 'contains review_accepted' do
      expect(maintenance_statistics[1].type).to eq(:review_accepted)
      expect(maintenance_statistics[1].when).to eq(review.updated_at)
    end

    it 'contains review_opened' do
      expect(maintenance_statistics[2].type).to eq(:review_opened)
      expect(maintenance_statistics[2].when).to eq(review.created_at)
    end

    it 'contains release_request_HistoryElement::RequestAccepted' do
      expect(maintenance_statistics[3].type)
        .to eq('release_request_HistoryElement::RequestAccepted')
      expect(maintenance_statistics[3].when).to eq(history_element_request_accepted.created_at)
    end

    it 'contains release_request_HistoryElement::RequestCreated' do
      expect(maintenance_statistics[4].type)
        .to eq('release_request_HistoryElement::RequestCreated')
      expect(maintenance_statistics[4].when).to eq(history_element_request_created.created_at)
    end

    it 'contains release_request_created' do
      expect(maintenance_statistics[5].type).to eq(:release_request_created)
      expect(maintenance_statistics[5].when).to eq(bs_request.created_at)
    end

    it 'contains project_created' do
      expect(maintenance_statistics[6].type).to eq(:project_created)
      expect(maintenance_statistics[6].when).to eq(project.created_at)
    end
  end
end
