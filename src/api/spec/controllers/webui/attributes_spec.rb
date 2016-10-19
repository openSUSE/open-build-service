require 'rails_helper'

RSpec.describe Webui::AttributeController do
  let!(:user) { create(:confirmed_user) }

  describe 'GET index' do
    it 'shows an error message when package does not exist' do
      get :index, params: { project: user.home_project, package: "Pok" }
      expect(response).to redirect_to(project_show_path(user.home_project))
      expect(flash[:error]).to eq("Package Pok not found")
    end

    it 'shows an error message when project does not exist' do
      get :index, params: { project: "Does:Not:Exist" }
      expect(response).to redirect_to(projects_path)
      expect(flash[:error]).to eq("Project not found: Does:Not:Exist")
    end
  end
end
