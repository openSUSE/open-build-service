require 'rails_helper'

RSpec.describe SourceProjectController, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { user.home_project }

  describe 'GET #show_project_meta' do
    before do
      login user
      get :show_project_meta, params: { project: project }
    end

    it { expect(response).to be_success }
    it { expect(Xmlhash.parse(response.body)['name']).to eq(project.name) }
  end
end
