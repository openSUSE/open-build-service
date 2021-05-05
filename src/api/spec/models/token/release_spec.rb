require 'rails_helper'

RSpec.describe Token::Release, vcr: true do
  let(:user) { create(:user, login: 'foo') }

  let(:project_staging) { create(:project_with_package, name: 'Bar:Staging', package_name: 'bar_package', maintainer: user) }
  let(:target_project) { create(:project, name: 'Bar', maintainer: user) }
  let(:package) { project_staging.packages.first }

  let(:repository) { create(:repository, name: 'package_test_repository', architectures: ['x86_64'], project: project_staging) }
  let(:target_repository) { create(:repository, name: 'target_repository', project: target_project) }

  subject { create(:release_token, package: package, user: user).call(package: package) }

  describe '#call' do
    context 'when no release target is set' do
      it 'throws an exception' do
        expect { subject }.to raise_error(Token::Errors::NoReleaseTargetFound, 'Bar:Staging has no release targets that are triggered manually')
      end
    end

    context 'when no manual release target is set' do
      let!(:release_target) { create(:release_target, target_repository: target_repository, repository: repository) }

      it 'throws an exception' do
        expect { subject }.to raise_error(Token::Errors::NoReleaseTargetFound, 'Bar:Staging has no release targets that are triggered manually')
      end
    end

    context 'when a manual release target is set' do
      let!(:release_target) { create(:release_target, target_repository: target_repository, repository: repository, trigger: 'manual') }
      let(:backend_url) do
        "/build/#{target_project.name}/#{target_repository.name}/x86_64/#{package.name}" \
          "?cmd=copy&oproject=#{CGI.escape(project_staging.name)}&opackage=#{package.name}&orepository=#{repository.name}" \
          '&resign=1&multibuild=1'
      end

      before do
        allow(Backend::Connection).to receive(:post).and_call_original
        allow(Backend::Connection).to receive(:post).with(backend_url).and_return("<status code=\"ok\" />\n")
      end

      it 'triggers the release process in the backend' do
        user.run_as do
          expect(subject.first).to have_attributes(repository_id: repository.id, target_repository_id: target_repository.id)
        end
      end
    end
  end
end
