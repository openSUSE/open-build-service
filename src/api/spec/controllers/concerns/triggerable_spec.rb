RSpec.describe Triggerable do
  # NOTE: this concern is not only used from controllers, also from models
  let(:fake_controller) do
    Class.new(ApplicationController) do
      include Triggerable
      include Trigger::Errors
    end
  end

  let(:fake_controller_instance) { fake_controller.new }

  let(:user) { create(:confirmed_user, login: 'foo') }
  let(:project_name) { 'project' }
  let(:package_name) { 'package_trigger' }
  let(:project) { create(:project, name: project_name, maintainer: user) }
  let(:package) { create(:package, name: package_name, project: project) }
  let(:repository) { create(:repository, name: 'package_test_repository', architectures: ['x86_64'], project: project) }

  before do
    fake_controller_instance.instance_variable_set(:@token, token)
    fake_controller_instance.instance_variable_set(:@project_name, project_name)
    fake_controller_instance.instance_variable_set(:@package_name, package_name)
  end

  def stub_params(project_name:, package_name:)
    stubbed_params = ActionController::Parameters.new(project: project_name, package: package_name)
    allow(fake_controller_instance).to receive(:params).and_return(stubbed_params)
  end

  describe '#set_project' do
    let(:token) { Token::Rebuild.create(executor: user) }

    context 'raises for remote projects' do
      before do
        allow(Project).to receive(:get_by_name).and_return('some:remote:project')
        stub_params(project_name: 'some:remote:project', package_name: package.name)
      end

      it { expect { fake_controller_instance.set_project }.to raise_error(Project::Errors::UnknownObjectError, 'Sorry, triggering tokens for remote project "project" is not possible.') }
    end

    context 'raises if token.package.project is not equal to project param' do
      before do
        stub_params(project_name: project.name, package_name: package.name)
        token.package = create(:package)
      end

      it { expect { fake_controller_instance.set_project }.to raise_error(Trigger::Errors::InvalidProject) }
    end
  end

  describe '#set_package' do
    let(:token) { Token::Service.create(executor: user) }
    let(:package_name) { 'does-not-exist' }

    it 'raises when package does not exist' do
      stub_params(project_name: project.name, package_name: package_name)
      fake_controller_instance.set_project
      expect { fake_controller_instance.set_package }.to raise_error(Package::Errors::UnknownObjectError)
    end

    context 'raises if token.package is not equal to package param' do
      before do
        token.package = create(:package, project: project)
        stub_params(project_name: project.name, package_name: package.name)
        fake_controller_instance.set_project
      end

      it { expect { fake_controller_instance.set_package }.to raise_error(Trigger::Errors::InvalidPackage) }
    end

    context 'project with project-link and token that follows project-links' do
      let(:token) { Token::Rebuild.create(executor: user) }
      let(:package_name) { 'does-not-exist' }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: project) }

      it 'raises when package does not exist in link' do
        stub_params(project_name: project_with_a_link.name, package_name: package_name)
        fake_controller_instance.set_project

        expect { fake_controller_instance.set_package }.to raise_error(Package::Errors::UnknownObjectError)
      end

      it 'assigns linked package' do
        stub_params(project_name: project_with_a_link.name, package_name: package.name)
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        expect(fake_controller_instance.instance_variable_get(:@package)).to eq(package)
      end
    end

    context 'project with remote project-link' do
      let(:token) { Token::Rebuild.create(executor: user) }
      let(:project_name) { 'project_with_a_link' }
      let(:package_name) { 'remote_package_trigger' }

      let(:project_with_a_link) { create(:project, name: project_name, maintainer: user, link_to: 'some:remote:project') }

      it 'assigns remote package string' do
        stub_params(project_name: project_with_a_link.name, package_name: package_name)
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        expect(fake_controller_instance.instance_variable_get(:@package)).to eq('remote_package_trigger')
      end
    end

    context 'project with scmsync link' do
      let(:token) { Token::Rebuild.create(executor: user) }
      let(:project_name) { 'project_with_scmsync' }
      let(:package_name) { 'some-scm-package' }

      let(:project_with_scmsync) { create(:project, name: project_name, maintainer: user, scmsync: 'https://github.com/hennevogel/scmsync-project.git') }

      it 'assigns remote package string' do
        stub_params(project_name: project_with_scmsync.name, package_name: package_name)
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        expect(fake_controller_instance.instance_variable_get(:@package)).to eq('some-scm-package')
      end
    end
  end

  describe '#set_object_to_authorize' do
    let(:token) { Token::Service.create(executor: user) }
    let(:local_package) { create(:package, name: 'local_package', project: project_with_a_link) }

    it 'assigns associated package' do
      stub_params(project_name: project.name, package_name: package.name)
      fake_controller_instance.set_project
      fake_controller_instance.set_package
      fake_controller_instance.set_object_to_authorize
      expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(package)
    end

    context 'project with project-link' do
      let(:token) { Token::Rebuild.create(executor: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: project) }

      before do
        fake_controller_instance.instance_variable_set(:@project_name, 'project_with_a_link')
      end

      it 'authorizes the project if the package is from a project with a link' do
        stub_params(project_name: project_with_a_link.name, package_name: package.name)
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        fake_controller_instance.set_object_to_authorize
        expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(project_with_a_link)
      end
    end

    context 'project with project-link and a local package' do
      let(:token) { Token::Rebuild.create(executor: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: project) }

      before do
        fake_controller_instance.instance_variable_set(:@project_name, 'project_with_a_link')
        fake_controller_instance.instance_variable_set(:@package_name, local_package.name)
      end

      it 'authorizes the package if the package is local' do
        stub_params(project_name: project_with_a_link.name, package_name: local_package.name)
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        fake_controller_instance.set_object_to_authorize
        expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(local_package)
      end
    end

    context 'project with remote project-link' do
      let(:token) { Token::Rebuild.create(executor: user) }
      let(:package_name) { 'some-remote-package-that-might-exist' }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: 'some:remote:project') }

      before do
        fake_controller_instance.instance_variable_set(:@project_name, 'project_with_a_link')
      end

      it 'authorizes the project if the package is from a project with a link' do
        stub_params(project_name: project_with_a_link.name, package_name: package_name)
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        fake_controller_instance.set_object_to_authorize
        expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(project_with_a_link)
      end
    end

    context 'project with remote project-link and local package' do
      let(:token) { Token::Rebuild.create(executor: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: 'some:remote:project') }

      before do
        fake_controller_instance.instance_variable_set(:@project_name, 'project_with_a_link')
        fake_controller_instance.instance_variable_set(:@package_name, local_package.name)
      end

      it 'authorizes the package if the package is local' do
        stub_params(project_name: project_with_a_link.name, package_name: local_package.name)
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        fake_controller_instance.set_object_to_authorize
        expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(local_package)
      end
    end
  end

  describe '#set_multibuild_flavor' do
    let(:multibuild_package) { create(:multibuild_package, name: 'package_a', project: project, flavors: %w[libfoo1 libfoo2]) }
    let(:multibuild_flavor) { 'libfoo2' }

    context 'with a token that allows multibuild' do
      let(:token) { Token::Rebuild.create(executor: user) }

      before do
        fake_controller_instance.instance_variable_set(:@package_name, "#{multibuild_package.name}:#{multibuild_flavor}")
        stub_params(project_name: project.name, package_name: "#{multibuild_package.name}:#{multibuild_flavor}")
      end

      it 'assigns flavor name' do
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        fake_controller_instance.set_object_to_authorize
        fake_controller_instance.set_multibuild_flavor
        expect(fake_controller_instance.instance_variable_get(:@multibuild_container)).to eq(multibuild_flavor)
      end

      it 'authorizes package object' do
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        fake_controller_instance.set_object_to_authorize
        fake_controller_instance.set_multibuild_flavor
        expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(multibuild_package)
      end
    end

    context 'with a token that does not allow multibuild' do
      let(:token) { Token::Service.create(executor: user) }

      it 'raises not found' do
        stub_params(project_name: project.name, package_name: multibuild_flavor)
        fake_controller_instance.set_project
        expect { fake_controller_instance.set_package }.to raise_error(Package::Errors::UnknownObjectError)
      end
    end
  end
end
