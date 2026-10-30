RSpec.describe Triggerable do
  # NOTE: this concern is not only used from controllers, also from models
  let(:fake_controller) do
    Class.new(ApplicationController) do
      include Triggerable
      include Trigger::Errors
    end
  end
  let(:fake_controller_instance) { fake_controller.new }
  let(:user) { create(:confirmed_user) }

  before do
    fake_controller_instance.instance_variable_set(:@token, token)
  end

  describe '#set_project' do
    let(:token) { Token::Rebuild.create(executor: user) }

    before do
      fake_controller_instance.instance_variable_set(:@project_name, 'i:dont:exist')
    end

    it { expect { fake_controller_instance.set_project }.to raise_error(Project::Errors::UnknownObjectError) }
  end

  describe '#set_package' do
    let(:token) { Token::Rebuild.create(executor: user) }

    context 'raises when package does not exist' do
      let(:project) { create(:project) }

      before do
        fake_controller_instance.instance_variable_set(:@project_name, project.name)
        fake_controller_instance.set_project
        fake_controller_instance.instance_variable_set(:@package_name, 'i-dont-exist')
      end

      it { expect { fake_controller_instance.set_package }.to raise_error(Package::Errors::UnknownObjectError) }
    end

    context 'supports project links' do
      let(:project) { create(:project, link_to: project_link_target) }
      let(:package) { create(:package, project: project_link_target) }
      let(:project_link_target) { create(:project) }

      before do
        fake_controller_instance.instance_variable_set(:@project_name, project.name)
        fake_controller_instance.set_project
        fake_controller_instance.instance_variable_set(:@package_name, package.name)
        fake_controller_instance.set_package
      end

      it { expect(fake_controller_instance.instance_variable_get(:@package)).to eq(package) }
      it { expect(fake_controller_instance.instance_variable_get(:@project)).to eq(project) }
      it { expect(fake_controller_instance.instance_variable_get(:@package).project).to eq(project_link_target) }
    end

    context 'supports remote project links' do
      let(:project) { create(:project, link_to: 'some:remote:project') }

      before do
        fake_controller_instance.instance_variable_set(:@project_name, project.name)
        fake_controller_instance.set_project
        fake_controller_instance.instance_variable_set(:@package_name, 'remote_package_trigger')
        fake_controller_instance.set_package
      end

      it { expect(fake_controller_instance.instance_variable_get(:@package)).to eq('remote_package_trigger') }
    end

    context 'supports project with scmsync link' do
      let(:project) { create(:project, scmsync: 'https://github.com/hennevogel/scmsync-project.git') }

      before do
        fake_controller_instance.instance_variable_set(:@project_name, project.name)
        fake_controller_instance.set_project
        fake_controller_instance.instance_variable_set(:@package_name, 'some-scm-package')
        fake_controller_instance.set_package
      end

      it { expect(fake_controller_instance.instance_variable_get(:@package)).to eq('some-scm-package') }
    end
  end

  describe '#set_object_to_authorize' do
    let(:token) { Token::Service.create(executor: user) }

    context 'for a project' do
      let(:package) { create(:package) }

      before do
        fake_controller_instance.instance_variable_set(:@project, package.project)
        fake_controller_instance.instance_variable_set(:@package, package)
        fake_controller_instance.set_object_to_authorize
      end

      it { expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(package) }
    end

    context 'for a project link' do
      let(:project) { create(:project, link_to: project_link_target) }
      let(:project_link_target) { create(:project) }
      let(:package) { create(:package, project: project_link_target) }

      before do
        fake_controller_instance.instance_variable_set(:@project, project)
        fake_controller_instance.instance_variable_set(:@package, package)
        fake_controller_instance.set_object_to_authorize
      end

      it { expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(project) }
      it { expect(fake_controller_instance.instance_variable_get(:@package).project).to eq(project_link_target) }
    end

    context 'for a remote project link' do
      let(:project) { create(:project, link_to: 'some:remote:project') }

      before do
        fake_controller_instance.instance_variable_set(:@project, project)
        fake_controller_instance.instance_variable_set(:@package, 'remote-package')
        fake_controller_instance.set_object_to_authorize
      end

      it 'authorizes the project if the package is from a project with a link' do
        expect(fake_controller_instance.instance_variable_get(:@token).object_to_authorize).to eq(project)
      end
    end
  end
end
