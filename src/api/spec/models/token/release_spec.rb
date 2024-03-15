RSpec.describe Token::Release, :vcr do
  subject { token.call(package: package) }

  let(:user) { create(:user, login: 'foo') }

  let(:project_staging) { create(:project_with_package, name: 'Bar:Staging', package_name: 'bar_package', maintainer: user) }
  let(:target_project) { create(:project, name: 'Bar', maintainer: user) }
  let(:package) { project_staging.packages.first }

  let(:repository) { create(:repository, name: 'package_test_repository', architectures: ['x86_64'], project: project_staging) }
  let(:target_repository) { create(:repository, name: 'target_repository', architectures: ['x86_64'], project: target_project) }

  let(:token) { create(:release_token, package: package, executor: user) }

  describe '#call' do
    context 'when no release target is set' do
      it 'throws an exception and sets the triggered_at column' do
        expect { subject }.to raise_error(Token::Errors::NoReleaseTargetFound, 'Bar:Staging has no release targets that are triggered manually')
          .and(change(token, :triggered_at))
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

      it 'records the current date and time in the triggered_at column' do
        user.run_as do
          expect { subject }.to change(token, :triggered_at)
        end
      end
    end

    context 'when the release target is provided through parameters' do
      let(:other_target_project) { create(:project, name: 'Baz', maintainer: user) }
      let(:other_source_repository) { create(:repository, name: 'other_source_repository', architectures: ['x86_64'], project: project_staging) }
      let(:other_target_repository) { create(:repository, name: 'other_target_repository', architectures: ['x86_64'], project: other_target_project) }
      let(:backend_url) do
        "/build/#{other_target_project.name}/#{other_target_repository.name}/x86_64/#{package.name}" \
          "?cmd=copy&oproject=#{CGI.escape(project_staging.name)}&opackage=#{package.name}&orepository=#{other_source_repository.name}" \
          '&resign=1&multibuild=1'
      end
      let!(:release_target) { create(:release_target, target_repository: other_target_repository, repository: other_source_repository, trigger: 'manual') }

      before do
        allow(Backend::Connection).to receive(:post).and_call_original
        allow(Backend::Connection).to receive(:post).with(backend_url).and_return("<status code=\"ok\" />\n")
      end

      context 'when the target_project, targetrepository, filter_source_repository and arch parameters are provided' do
        subject do
          token.call(package: package, project: project_staging, targetproject: 'Baz', targetrepository: 'other_target_repository', filter_source_repository: 'other_source_repository')
        end

        it 'triggers the release process in the backend' do
          user.run_as do
            subject
          end

          expect(Backend::Connection).to have_received(:post).with(backend_url)
        end
      end

      context 'when the user can not modify the target_repository' do
        subject do
          token.call(package: package, project: project_staging, targetproject: 'Foo', targetrepository: 'other_target_repository', filter_source_repository: 'other_source_repository')
        end

        let(:other_target_project) { create(:project, name: 'Foo') }
        let(:other_target_repository) { create(:repository, name: 'other_target_repository', project: other_target_project) }

        it 'does not trigger the release process in the backend' do
          user.run_as do
            expect { subject }.to raise_error(Token::Errors::InsufficientPermissionOnTargetRepository, 'no permission to write in project Foo')
            expect(Backend::Connection).not_to have_received(:post).with(backend_url)
          end
        end
      end

      context 'when the architecture is provided through parameters and is not included in the target repository' do
        subject do
          token.call(package: package, project: project_staging, targetproject: 'Baz', targetrepository: 'other_target_repository', filter_source_repository: 'other_source_repository',
                     arch: 's390x')
        end

        it 'does not trigger the release process in the backend' do
          user.run_as do
            expect(Backend::Connection).not_to have_received(:post).with(backend_url)
          end
        end
      end

      context 'when the architecture is provided through parameters and is included in the target repository' do
        subject do
          token.call(package: package, project: project_staging, targetproject: 'Baz', targetrepository: 'other_target_repository', filter_source_repository: 'other_source_repository',
                     arch: 'x86_64')
        end

        it 'triggers the release process in the backend' do
          user.run_as do
            subject
          end
          expect(Backend::Connection).to have_received(:post).with(backend_url)
        end
      end
    end
  end
end
