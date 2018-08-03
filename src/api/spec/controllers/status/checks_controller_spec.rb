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
    it 'assigns @checks' do
      check1 = create(:check, checkable: status_repository_publish)
      check2 = create(:check, checkable: status_repository_publish)
      get :index, params: { project_name: project.name,
                            repository_name: repository.name,
                            status_repository_publish_build_id: status_repository_publish.build_id }, format: :xml
      expect(assigns(:checkable).checks).to eq([check1, check2])
    end
  end

  describe 'GET show' do
    it 'assigns @check' do
      check = create(:check, checkable: status_repository_publish)
      get :show, params: { project_name: project.name,
                           repository_name: repository.name,
                           status_repository_publish_build_id: status_repository_publish.build_id,
                           id: check.id }, format: :xml
      expect(assigns(:check)).to eq(check)
    end
  end

  describe 'POST update' do
    let(:check_xml) do
      file_fixture('check.xml').read
    end

    it 'will create checkable on POST' do
      expect do
        post :update, body: check_xml, params: { project_name: project.name,
                                                 repository_name: repository.name,
                                                 status_repository_publish_build_id: 6789 }, format: :xml
      end.to change(Status::RepositoryPublish, :count).by(1)
      expect(repository.status_publishes.first.build_id).to eq('6789')
    end

    it 'will create check on POST' do
      expect do
        post :update, body: check_xml, params: { project_name: project.name,
                                                 repository_name: repository.name,
                                                 status_repository_publish_build_id: 1312 }, format: :xml
      end.to change(Status::Check, :count).by(1)
      expect(repository.status_publishes.first.checks.first.url).to eq('http://checks.example.com/12345')
    end
  end

  describe 'DELETE destroy' do
    skip
  end
end
