require 'rails_helper'

RSpec.describe SourceProjectController, vcr: true do
  render_views
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:user_1) { create(:confirmed_user, login: 'tom_1') }
  let(:project) { user.home_project }

  describe '#show' do
    before do
      login user
      get :show, params: { project: project.name, format: :xml }
    end

    it { expect(response).to be_success }
  end

  describe '#delete' do
    context 'when you are not allowed to' do
      before do
        login user_1
        delete :delete, params: { project: project.name, format: :xml }
      end

      it { expect(response).to have_http_status(403) }
      it { expect(response.body).to eq("<status code=\"delete_project_not_authorized\">\n  <summary>You are not authorized to delete this project</summary>\n</status>\n") }
    end

    context 'when there is no maintainer in the project' do
      before do
        login user
        project.update_from_xml(Xmlhash.parse("<project name='#{project.name}'></project>"))
        project.store
        delete :delete, params: { project: project.name, format: :xml }
      end

      it { expect(response).to have_http_status(403) }
      it { expect(response.body).to eq("<status code=\"delete_project_not_authorized\">\n  <summary>You are not authorized to delete this project</summary>\n</status>\n") }
    end

    context 'when you are allowed to' do
      before do
        login user
        delete :delete, params: { project: project.name, format: :xml }
      end

      it { expect(response).to be_success }
    end
  end
end
