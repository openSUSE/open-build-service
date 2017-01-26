require 'rails_helper'

RSpec.describe Statistics::MaintenanceStatistic do
  describe '.find_by_project' do
    include_context 'a project with maintenance statistics'

    subject(:maintenance_statistics) { Statistics::MaintenanceStatistic.find_by_project(project) }

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

    it 'contains release_request_request_accepted' do
      expect(maintenance_statistics[3].type).to eq('release_request_request_accepted')
      expect(maintenance_statistics[3].when).to eq(history_element_request_accepted.created_at)
    end

    it 'contains release_request_request_created' do
      expect(maintenance_statistics[4].type).to eq('release_request_request_created')
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
