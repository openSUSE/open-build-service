require 'rails_helper'

# CONFIG['global_write_through'] = true

RSpec.describe SourceProjectMetaController, vcr: true do
  render_views

  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { user.home_project }

  describe 'GET #show' do
    before do
      login user
      get :show, params: { project: project }
    end

    it { expect(response).to be_success }
    it { expect(Xmlhash.parse(response.body)['name']).to eq(project.name) }
  end

  describe 'PUT #update' do
    let(:meta) do
      <<~META
        <project name="#{project.name}">
          <title>My cool project</title>
          <description></description>
          <person userid="#{user.login}" role="maintainer" />
        </project>
      META
    end
    before do
      login user
      put :update, params: { project: project }, body: meta, format: :xml
    end

    it { expect(response).to be_success }
    it { expect(project.meta.content).to eq(meta) }
  end
end
