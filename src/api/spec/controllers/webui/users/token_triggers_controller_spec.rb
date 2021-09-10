require 'rails_helper'

RSpec.describe Webui::Users::TokenTriggersController, vcr: true, type: :controller do
  RSpec.shared_examples 'token got triggered' do
    it 'flashes success and redirects to token_path' do
      expect(flash[:success]).to eq("Token with id #{token.id} successfully triggered!")
      expect(response).to redirect_to(tokens_path)
    end
  end

  describe 'PUT #update' do
    let(:token_user) { create(:confirmed_user, login: 'foo') }
    let(:token_project) { create(:project, name: 'test-project', maintainer: token_user) }
    let(:token_package) { create(:package, name: 'test-package', project: token_project) }
    let(:repository) { create(:repository, name: 'package_test_repository', architectures: ['x86_64'], project: token_project) }

    before do
      login token_user
    end

    context 'when package or project params are not provided' do
      supported_token_classes = [Token::Rebuild, Token::Release, Token::Service]

      supported_token_classes.each do |token_class|
        let(:token) { token_class.create(user: token_user) }

        it 'flashes error when package param is missing' do
          put :update, params: { id: token.id, project: token_project.name }

          expect(flash[:error]).to eq("Package not found: #{token_project.name}/")
          expect(response).to redirect_to(tokens_path)
        end

        it 'flashes error when project param is missing' do
          put :update, params: { id: token.id, package: token_package.name }

          expect(flash[:error]).to eq('Project not found: ')
          expect(response).to redirect_to(tokens_path)
        end
      end
    end

    context 'rebuild token' do
      context 'when token is valid and associated package exist' do
        let(:token) { create(:rebuild_token, user: token_user, package: token_package) }

        before do
          allow(Backend::Api::Sources::Package).to receive(:rebuild).and_return("<status code=\"ok\" />\n")
          put :update, params: { id: token.id }
        end

        include_examples 'token got triggered'
      end

      context 'when token is valid and package/project provided exist' do
        let(:token) { create(:rebuild_token, user: token_user, package: nil) }

        before do
          allow(Backend::Api::Sources::Package).to receive(:rebuild).and_return("<status code=\"ok\" />\n")
          put :update, params: { id: token.id, package: token_package.name, project: token_project.name }
        end

        include_examples 'token got triggered'
      end
    end

    context 'release token' do
      let(:target_project) { create(:project, name: 'target_project', maintainer: token_user) }
      let(:target_repository) { create(:repository, name: 'target_repository', project: target_project) }
      let(:release_target) { create(:release_target, repository: repository, target_repository: target_repository, trigger: 'manual') }

      context 'when token is valid and associated package exist' do
        let(:token) { Token::Release.create(user: token_user, package: token_package) }

        let(:backend_url) do
          "/build/#{target_project.name}/#{target_repository.name}/x86_64/#{token_package.name}" \
            "?cmd=copy&oproject=#{CGI.escape(token_project.name)}&opackage=#{token_package.name}&orepository=#{repository.name}" \
            '&resign=1&multibuild=1'
        end

        before do
          release_target
          allow(Backend::Connection).to receive(:post).and_call_original
          allow(Backend::Connection).to receive(:post).with(backend_url).and_return("<status code=\"ok\" />\n")
          put :update, params: { id: token.id }
        end

        include_examples 'token got triggered'
      end

      context 'when user has no rights for source' do
        let(:other_user) { create(:confirmed_user, login: 'mrfluffy') }
        let(:token) { Token::Release.create(user: other_user, package: token_package) }

        before do
          login other_user
          release_target
          put :update, params: { id: token.id }
        end

        it 'flashes an error' do
          expect(flash[:error]).to eq("Failed to trigger token: No permission to modify project 'target_project' for user 'mrfluffy'")
          expect(response).to redirect_to(tokens_path)
        end
      end

      context 'when user has no rights for target' do
        let(:other_user) { create(:confirmed_user, login: 'mrfluffy') }
        let!(:relationship_package_user) { create(:relationship_package_user, user: other_user, package: token_package) }
        let(:token) { Token::Release.create(user: other_user, package: token_package) }

        before do
          login other_user
          release_target
          put :update, params: { id: token.id }
        end

        it 'flashes an error' do
          expect(flash[:error]).to eq("Failed to trigger token: No permission to modify project 'target_project' for user 'mrfluffy'")
          expect(response).to redirect_to(tokens_path)
        end
      end

      context 'when there are no release targets' do
        let(:other_user) { create(:confirmed_user, login: 'mrfluffy') }
        let(:token) { Token::Release.create(user: other_user, package: token_package) }
        let!(:relationship_package_user) { create(:relationship_package_user, user: other_user, package: token_package) }

        before do
          login other_user
          put :update, params: { id: token.id }
        end

        it 'flashes an error' do
          expect(flash[:error]).to eq("Failed to trigger token: #{token_package.project} has no release targets that are triggered manually")
          expect(response).to redirect_to(tokens_path)
        end
      end
    end

    context 'service token' do
      before do
        put :update, params: { id: token.id }
      end

      context 'when package provides a service' do
        let(:package_with_service) { create(:package_with_service, name: 'package_with_service', project: token_project) }
        let(:token) { Token::Service.create(user: token_user, package: package_with_service) }

        include_examples 'token got triggered'
      end

      context 'when package does not provide a service' do
        let(:token) { Token::Service.create(user: token_user, package: token_package) }

        it 'flashes an error' do
          expect(flash[:error]).to eq('Failed to trigger token: no source service defined!')
          expect(response).to redirect_to(tokens_path)
        end
      end
    end
  end
end
