require 'rails_helper'

RSpec.describe Worker::CommandController do
  let(:user) { create(:confirmed_user) }

  let(:backend_body) do
    <<~XML
      <directory>
        <entry name="x86_64:7de14aea3d12:1" />
        <entry name="x86_64:7de14aea3d12:2" />
      </directory>
    XML
  end

  let!(:project) do
    create(:project_with_repository, maintainer: user) do |project|
      project.store
      project.packages.create(attributes_for(:package))
    end
  end

  let(:package) { project.packages.first }

  let(:repository) { project.repositories.first }

  let(:backend_response) do
    instance_double('Net::HTTPResponse', body: backend_body)
  end

  before do
    allow(backend_response).to receive(:fetch).and_return('text/xml')
    allow(Backend::Connection).to receive(:post).and_return(backend_response)
    login user
  end

  describe 'POST /run' do
    context 'valid command' do
      subject! do
        post :run, params: { cmd: 'checkconstraints', project: project.name,
                             package: package.name, repository: repository.name,
                             arch: 'i586', format: :xml }
      end

      it { is_expected.to have_http_status(:success) }
    end

    context 'invalid command' do
      subject! do
        post :run, params: { cmd: 'foo', project: 'foo',
                             package: 'bar', repository: 'my-repo',
                             arch: 'i586', format: :xml }
      end

      it { is_expected.to have_http_status(:bad_request) }
    end
  end
end
