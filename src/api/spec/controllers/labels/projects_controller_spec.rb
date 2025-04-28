RSpec.describe Labels::ProjectsController do
  let(:user) { create(:confirmed_user, :with_home) }
  let(:admin_user) { create(:admin_user, :with_home) }
  let(:label_template) { create(:label_template_global) }
  let(:second_label_template) { create(:label_template_global) }
  let!(:label_admin) { create(:label_global, label_template_global: label_template, project: admin_user.home_project) }

  before do
    Flipper.enable(:labels, user)
    Flipper.enable(:labels, admin_user)
  end

  describe 'GET #index' do
    render_views

    context 'when labels are present' do
      before do
        login user

        get :index, params: { project_name: admin_user.home_project.name, format: 'xml' }
      end

      it 'includes label in response body' do
        expect(Xmlhash.parse(response.body)).to have_key('label')
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, body: create_label_xml, params: { project_name: admin_user.home_project.name, format: 'xml' } }

    let(:create_label_xml) do
      <<~XML
        <label label_template_id="#{second_label_template.id}" />
      XML
    end

    context 'when the user has the necessary permissions' do
      before do
        login admin_user
      end

      it 'successfully creates a new label' do
        expect { subject }.to change(LabelGlobal, :count).by(1)
      end
    end

    context 'when the user lacks the necessary permissions' do
      before do
        login user
      end

      it 'returns an error' do
        expect(subject).to have_http_status(:forbidden)
      end

      it 'does not create a new label' do
        expect { subject }.not_to change(LabelGlobal, :count)
      end
    end

    context 'when XML is missing required attributes' do
      let(:invalid_xml) { '<label />' }

      before do
        login admin_user
        post :create, body: invalid_xml, params: { project_name: admin_user.home_project.name, format: 'xml' }
      end

      it 'returns an error' do
        expect(response).to have_http_status(:bad_request)
        expect(response.headers['X-Opensuse-Errorcode']).to eq('invalid_xml_format')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when the user is authorized' do
      before do
        login admin_user

        delete :destroy, params: { project_name: admin_user.home_project.name, id: label_admin.id, format: :xml }
      end

      it 'deletes the label' do
        expect(response).to have_http_status(:ok)
        expect(label_template.reload.labels.count).to eq(0)
      end
    end

    context 'when the user is not authorized' do
      before do
        login user

        delete :destroy, params: { project_name: admin_user.home_project.name, id: label_admin.id, format: :xml }
      end

      it 'does not delete the label and returns an error' do
        expect(response).to have_http_status(:forbidden)
        expect(label_template.reload.labels.count).to eq(1)
      end
    end
  end
end
