RSpec.describe SourceCommandController do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }

  describe 'POST #global_command_orderkiwirepos', :vcr do
    it 'is accessible anonymously and forwards backend errors' do
      post :global_command_orderkiwirepos, params: { cmd: 'orderkiwirepos' }
      expect(response).to have_http_status(:bad_request)
      expect(Xmlhash.parse(response.body)['summary']).to eq('read_file: no content attached')
    end
  end

  describe 'POST #global_command_branch' do
    it 'is not accessible anonymously' do
      post :global_command_branch, params: { cmd: 'branch' }
      expect(flash[:error]).to eq('Anonymous user is not allowed here - please login (anonymous_user)')
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST #global_command_createmaintenanceincident' do
    it 'is not accessible anonymously' do
      post :global_command_createmaintenanceincident, params: { cmd: 'createmaintenanceincident' }
      expect(flash[:error]).to eq('Anonymous user is not allowed here - please login (anonymous_user)')
      expect(response).to redirect_to(root_path)
    end
  end
end
