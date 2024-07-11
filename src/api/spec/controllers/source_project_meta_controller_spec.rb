RSpec.describe SourceProjectMetaController, :vcr do
  render_views

  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:admin_user) { create(:admin_user) }

  describe 'GET #show' do
    subject { get :show, params: { project: project }, format: :xml }

    let(:project) { create(:project, maintainer: user) }

    before do
      login user
    end

    it { expect(Xmlhash.parse(subject.body)['name']).to eq(project.name) }
  end

  describe 'PUT #update' do
    subject { put :update, params: { project: 'top_project:a_new_project' }, body: meta, format: :xml }

    let(:meta) do
      <<~META
        <project name="top_project:a_new_project">
          <title>My cool new project</title>
          <description></description>
        </project>
      META
    end

    before do
      login admin_user
    end

    context 'to create a project' do
      it { expect { subject }.to change { Project.where(name: 'top_project:a_new_project').count }.from(0).to(1) }
    end

    context 'to create a project below an interconnect' do
      let!(:top_project) { create(:remote_project, name: 'top_project') }

      it { expect { subject }.to change { Project.where(name: 'top_project:a_new_project').count }.from(0).to(1) }
    end

    context 'to update a project' do
      subject { put :update, params: { project: 'home:tom' }, body: meta, format: :xml }

      let(:new_title) { Faker::Lorem.sentence }
      let(:meta) do
        <<~META
          <project name="home:tom">
            <title>#{new_title}</title>
            <description></description>
          </project>
        META
      end

      before do
        login user
      end

      it { expect(subject).to have_http_status(:success) }
      it { expect { subject }.to change { Project.find_by(name: 'home:tom').title }.to(new_title) }
    end
  end
end
