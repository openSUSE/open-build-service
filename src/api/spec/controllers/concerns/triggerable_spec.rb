require 'rails_helper'

RSpec.describe Triggerable do
  let(:fake_controller) do
    Class.new(ApplicationController) do
      include Triggerable
    end
  end

  let(:fake_controller_instance) { fake_controller.new }

  let(:user) { create(:confirmed_user, login: 'foo') }
  let(:project) { create(:project, name: 'project', maintainer: user) }
  let(:package) { create(:package, name: 'package_trigger', project: project) }
  let(:repository) { create(:repository, name: 'package_test_repository', architectures: ['x86_64'], project: project) }

  before do
    fake_controller_instance.instance_variable_set(:@token, token)
  end

  def stub_params(project_name:, package_name:)
    stubbed_params = ActionController::Parameters.new(project: project_name, package: package_name)
    allow(fake_controller_instance).to receive(:params).and_return(stubbed_params)
  end

  describe '#set_project' do
    let(:token) { Token::Rebuild.create(user: user) }

    before do
      allow(Project).to receive(:get_by_name).and_return('some:remote:project')
    end

    it 'raises a not found for a remote project' do
      stub_params(project_name: 'some:remote:project', package_name: package.name)
      expect { fake_controller_instance.set_project }.to raise_error(Project::Errors::UnknownObjectError)
    end
  end

  describe '#set_package' do
    let(:token) { Token::Service.create(user: user) }

    it 'raises when package does not exist' do
      stub_params(project_name: project.name, package_name: 'does-not-exist')
      fake_controller_instance.set_project
      expect { fake_controller_instance.set_package }.to raise_error(Package::Errors::UnknownObjectError)
    end

    context 'project with project-link and token that follows project-links' do
      let(:token) { Token::Rebuild.create(user: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: project) }

      it 'raises when package does not exist in link' do
        stub_params(project_name: project_with_a_link.name, package_name: 'does-not-exist')
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
      let(:token) { Token::Rebuild.create(user: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: 'some:remote:project') }

      it 'assigns remote package string' do
        stub_params(project_name: project_with_a_link.name, package_name: 'remote_package_trigger')
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        expect(fake_controller_instance.instance_variable_get(:@package)).to eq('remote_package_trigger')
      end
    end
  end

  describe '#set_object_to_authorize' do
    let(:token) { Token::Service.create(user: user) }
    let(:local_package) { create(:package, name: 'local_package', project: project_with_a_link) }

    it 'assigns associated package' do
      stub_params(project_name: project.name, package_name: package.name)
      fake_controller_instance.set_project
      fake_controller_instance.set_package
      fake_controller_instance.set_object_to_authorize
      expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(package)
    end

    context 'project with project-link' do
      let(:token) { Token::Rebuild.create(user: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: project) }

      it 'authorizes the project if the package is from a project with a link' do
        stub_params(project_name: project_with_a_link.name, package_name: package.name)
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        fake_controller_instance.set_object_to_authorize
        expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(project_with_a_link)
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
      let(:token) { Token::Rebuild.create(user: user) }
      let(:project_with_a_link) { create(:project, name: 'project_with_a_link', maintainer: user, link_to: 'some:remote:project') }

      it 'authorizes the project if the package is from a project with a link' do
        stub_params(project_name: project_with_a_link.name, package_name: 'some-remote-package-that-might-exist')
        fake_controller_instance.set_project
        fake_controller_instance.set_package
        fake_controller_instance.set_object_to_authorize
        expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(project_with_a_link)
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
    let(:multibuild_package) { create(:multibuild_package, name: 'package_a', project: project, flavors: ['libfoo1', 'libfoo2']) }
    let(:multibuild_flavor) { 'libfoo2' }

    context 'with a token that allows multibuild' do
      let(:token) { Token::Rebuild.create(user: user) }

      before do
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
      let(:token) { Token::Service.create(user: user) }

      it 'raises not found' do
        stub_params(project_name: project.name, package_name: multibuild_flavor)
        fake_controller_instance.set_project
        expect { fake_controller_instance.set_package }.to raise_error(Package::Errors::UnknownObjectError)
      end
    end
  end
end
