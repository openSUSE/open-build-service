require 'rails_helper'

RSpec.describe OpenRequestsWithProjectAsSourceOrTargetFinder do
  let(:target_project) { create(:project, name: 'target_project') }
  let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: target_project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }

  let(:request_attributes) do
    {
      target_package: target_package,
      source_package: source_package
    }
  end

  let!(:submit_request) { create(:bs_request_with_submit_action, request_attributes) }

  describe 'call' do
    subject do
      OpenRequestsWithProjectAsSourceOrTargetFinder.new(BsRequest.where(state: [:new, :review, :declined])
                                                       .joins(:bs_request_actions), project.name).call
    end

    context 'project as source' do
      let(:project) { source_project }

      it { expect(subject).not_to be_empty }
    end

    context 'project as target' do
      let(:project) { target_project }

      it { expect(subject).not_to be_empty }
    end
  end
end
