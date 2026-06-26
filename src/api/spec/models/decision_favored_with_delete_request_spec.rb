RSpec.describe DecisionFavoredWithDeleteRequest do
  let(:user) { create(:confirmed_user) }

  before { login user }

  context 'when reporting a package' do
    let(:decision) { create(:decision_favored_with_delete_request_for_package) }

    it 'creates a delete request for a package' do
      expect { decision.create_delete_request }.to change(BsRequest, :count)
      expect { decision.create_delete_request }.to change(BsRequestActionDelete, :count)
    end
  end

  context 'when reporting a project' do
    let(:decision) { create(:decision_favored_with_delete_request_for_project) }

    it 'creates a delete request for a project' do
      expect { decision.create_delete_request }.to change(BsRequest, :count)
      expect { decision.create_delete_request }.to change(BsRequestActionDelete, :count)
    end
  end
end
