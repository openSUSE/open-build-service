require 'rails_helper'

RSpec.describe Status::ChecksController, type: :controller do
  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project_with_repository) }
  let(:repository) { project.repositories.first }
  let(:status_repository_publish) { create(:status_repository_publish, repository: repository) }

  before do
    login user
  end

  describe 'GET index' do
    context 'with checks' do
      let(:check1) { create(:check, checkable: status_repository_publish) }
      let(:check2) { create(:check, checkable: status_repository_publish) }

      before do
        get :index, params: { project_name: project.name,
                              repository_name: repository.name,
                              status_repository_publish_build_id: status_repository_publish.build_id }, format: :xml
      end

      it { expect(assigns(:checks)).to include(check1) }
      it { expect(assigns(:checks)).to include(check2) }
    end

    context 'without checks' do
      before do
        get :index, params: { project_name: project.name,
                              repository_name: repository.name,
                              status_repository_publish_build_id: status_repository_publish.build_id }, format: :xml
      end

      it { expect(assigns(:checks)).to be_empty }
    end
  end

  describe 'GET show' do
    context 'when check exists' do
      let(:check) { create(:check, checkable: status_repository_publish) }

      before do
        get :show, params: { project_name: project.name,
                             repository_name: repository.name,
                             status_repository_publish_build_id: status_repository_publish.build_id,
                             id: check.id }, format: :xml
      end

      it { expect(assigns(:check)).to(eq(check)) }
    end

    context 'when check does not exists' do
      before do
        get :show, params: { project_name: project.name,
                             repository_name: repository.name,
                             status_repository_publish_build_id: status_repository_publish.build_id,
                             id: '42' }, format: :xml
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe 'POST create' do
    let(:check_xml) do
      file_fixture('check.xml').read
    end

    context 'successfully' do
      let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

      it 'will create checkable' do
        expect do
          post :create, body: check_xml, params: { project_name: project.name,
                                                   repository_name: repository.name,
                                                   status_repository_publish_build_id: 6789 }, format: :xml
        end.to change(Status::RepositoryPublish, :count).by(1)
        expect(repository.status_publishes.first.build_id).to eq('6789')
      end

      it 'will create check' do
        expect do
          post :create, body: check_xml, params: { project_name: project.name,
                                                   repository_name: repository.name,
                                                   status_repository_publish_build_id: 1312 }, format: :xml
        end.to change(Status::Check, :count).by(1)
        expect(repository.status_publishes.first.checks.first.url).to eq('http://checks.example.com/12345')
      end
    end

    shared_examples 'does not create checkable and check' do
      it 'will not create checkable' do
        expect do
          post :create, body: check_xml, params: { project_name: project.name,
                                                   repository_name: repository.name,
                                                   status_repository_publish_build_id: 6789 }, format: :xml
        end.not_to change(Status::RepositoryPublish, :count)
      end

      it 'will not create check' do
        expect do
          post :create, body: check_xml, params: { project_name: project.name,
                                                   repository_name: repository.name,
                                                   status_repository_publish_build_id: 1312 }, format: :xml
        end.not_to change(Status::Check, :count)
      end
    end

    context 'with invalid XML' do
      let!(:relationship) { create(:relationship_project_user, user: user, project: project) }
      let(:check_xml) do
        file_fixture('invalid_check.xml').read
      end

      include_context 'does not create checkable and check'
    end

    context 'with no permissions' do
      include_context 'does not create checkable and check'
    end
  end

  describe 'PUT update' do
    let(:check) { create(:check, state: 'pending', checkable: status_repository_publish) }

    context 'successfully' do
      let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

      before do
        put :update, body: '<check><state>success</state></check>', params: { project_name: project.name,
                                                 repository_name: repository.name,
                                                 status_repository_publish_build_id: status_repository_publish.build_id, id: check.id }, format: :xml
      end

      it { expect(check.reload.state).to eq('success') }
    end

    context 'without permissions' do
      before do
        put :update, body: '<check><state>success</state></check>', params: { project_name: project.name,
                                                 repository_name: repository.name,
                                                 status_repository_publish_build_id: status_repository_publish.build_id, id: check.id }, format: :xml
      end

      it { expect(check.reload.state).to eq('pending') }
      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'with invalid xml' do
      let!(:relationship) { create(:relationship_project_user, user: user, project: project) }
      before do
        put :update, body: '<check><state>not-allowed</state></check>', params: { project_name: project.name,
                                                 repository_name: repository.name,
                                                 status_repository_publish_build_id: status_repository_publish.build_id, id: check.id }, format: :xml
      end

      it { expect(check.reload.state).to eq('pending') }
      it { expect(response).to have_http_status(:unprocessable_entity) }
    end
  end

  describe 'DELETE destroy' do
    let!(:check) { create(:check, checkable: status_repository_publish) }

    context 'with permissions' do
      let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

      it 'will delete the check' do
        expect do
          delete :destroy, params: { project_name: project.name,
                                                   repository_name: repository.name,
                                                   status_repository_publish_build_id: status_repository_publish.build_id, id: check.id }, format: :xml
        end.to change(Status::Check, :count).by(-1)
      end
    end

    context 'without permissions' do
      it 'will not delete the check' do
        expect do
          delete :destroy, params: { project_name: project.name,
                                                   repository_name: repository.name,
                                                   status_repository_publish_build_id: status_repository_publish.build_id, id: check.id }, format: :xml
        end.not_to change(Status::Check, :count)
      end
    end
  end
end
