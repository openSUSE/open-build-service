RSpec.describe LabelTemplates::ProjectsController do
  let(:user) { create(:confirmed_user, :with_home) }
  let(:project) { user.home_project }
  let(:label_template1) { create(:label_template, color: '#112233', name: 'Template 1', project: project) }

  before do
    Flipper.enable(:labels, user)
  end

  describe 'PUT #update' do
    subject { put :update, params: { project_name: project.name, id: label_template1.id }, format: :xml, body: label_template_xml }

    let(:label_template_xml) do
      <<~XML
        <label_template>
          <color>#123567</color>
          <name>New name</name>
        </label_template>
      XML
    end

    before do
      login user
    end

    it 'updates the label template' do
      expect(subject).to have_http_status(:ok)
      expect(label_template1.reload.slice(:color, :name).symbolize_keys).to eq(color: '#123567', name: 'New name')
    end
  end
end
