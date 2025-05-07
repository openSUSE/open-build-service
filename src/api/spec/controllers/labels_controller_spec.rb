RSpec.describe LabelsController do
  let(:user) { create(:confirmed_user, :with_home) }
  let(:admin_user) { create(:admin_user, :with_home) }
  let(:label_template) { create(:label_template, project: admin_user.home_project) }
  let(:package) { create(:package, project: admin_user.home_project) }
  let!(:label) { create(:label, label_template: label_template, labelable: package) }

  before do
    Flipper.enable(:labels, user)
    Flipper.enable(:labels, admin_user)
  end

  describe 'GET #index' do
    render_views

    context 'when labels are present' do
      before do
        login user

        get :index, params: { project_name: admin_user.home_project.name, package_name: package.name, format: 'xml' }
      end

      it 'includes label in response body' do
        expect(Xmlhash.parse(response.body)).to have_key('label')
        expect(Xmlhash.parse(response.body)['label']['label_template_name']).to eq(label_template.name)
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, body: create_label_xml, params: { package_name: new_package.name, project_name: admin_user.home_project, format: 'xml' } }

    let(:new_package) { create(:package, project: admin_user.home_project) }
    let(:create_label_xml) do
      <<~XML
        <label label_template_id="#{label_template.id}" />
      XML
    end

    context 'when the user has the necessary permissions' do
      before do
        login admin_user
      end

      it 'successfully creates a new label' do
        expect { subject }.to change(Label, :count).by(1)
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
        expect { subject }.not_to change(Label, :count)
      end
    end

    context 'when XML is missing required attributes' do
      let(:invalid_xml) { '<label />' }

      before do
        login admin_user
        post :create, body: invalid_xml, params: { package_name: new_package.name, project_name: admin_user.home_project, format: 'xml' }
      end

      it 'returns an error' do
        expect(response).to have_http_status(:bad_request)
        expect(response.headers['X-Opensuse-Errorcode']).to eq('invalid_xml_format')
      end
    end

    context 'when labeling a bs_request with multiple target projects' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let(:source_package) { create(:package, project: user.home_project) }
      let(:submit_action) { create(:bs_request_action_submit, target_project: package.project, target_package: package, source_project: user.home_project, source_package: source_package) }
      let(:submit_action2) { create(:bs_request_action_submit, source_project: package.project, source_package: package, target_project: user.home_project, target_package: source_package) }

      before do
        login admin_user
        bs_request.bs_request_actions << submit_action
        bs_request.bs_request_actions << submit_action2

        post :create, body: create_label_xml, params: { request_number: bs_request.number, format: 'xml' }
      end

      it 'returns error' do
        expect(response.headers['X-Opensuse-Errorcode']).to eq('invalid_label')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when the user is authorized' do
      before do
        login admin_user

        delete :destroy, params: { project_name: admin_user.home_project, package_name: package.name, id: label.id, format: :xml }
      end

      it 'deletes the label' do
        expect(response).to have_http_status(:ok)
        expect(label_template.reload.labels.count).to eq(0)
      end
    end

    context 'when the user is not authorized' do
      before do
        login user

        delete :destroy, params: { project_name: admin_user.home_project, package_name: package.name, id: label.id, format: :xml }
      end

      it 'does not delete the label and returns an error' do
        expect(response).to have_http_status(:forbidden)
        expect(label_template.reload.labels.count).to eq(1)
      end
    end
  end
end
