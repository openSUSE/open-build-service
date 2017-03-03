require 'rails_helper'
# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe SourceController, vcr: true do
  describe "POST #global_command_orderkiwirepos" do
    it "is accessible anonymously and forwards backend errors" do
      post :global_command_orderkiwirepos, params: { cmd: "orderkiwirepos" }
      expect(response).to have_http_status(:bad_request)
      expect(Xmlhash.parse(response.body)["summary"]).to eq("read_file: no content attached")
    end
  end

  describe "POST #global_command_branch" do
    it "is not accessible anonymously" do
      post :global_command_branch, params: { cmd: "branch" }
      expect(flash[:error]).to eq("anonymous_user(Anonymous user is not allowed here - please login): ")
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST #global_command_createmaintenanceincident" do
    it "is not accessible anonymously" do
      post :global_command_createmaintenanceincident, params: { cmd: "createmaintenanceincident" }
      expect(flash[:error]).to eq("anonymous_user(Anonymous user is not allowed here - please login): ")
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #show_project_meta" do
    let(:user) { create(:confirmed_user, login: "tom") }
    let(:project) { user.home_project }

    before do
      login user
      get :show_project_meta, params: { project: project }
    end

    it { expect(response).to be_success }
    it { expect(Xmlhash.parse(response.body)["name"]).to eq(project.name) }
  end
end
