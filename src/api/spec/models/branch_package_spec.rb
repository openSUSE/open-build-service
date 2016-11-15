require 'rails_helper'

RSpec.describe BranchPackage, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:home_project) { user.home_project }
  let!(:project) { create(:project, name: 'BaseDistro') }
  let!(:package) { create(:package, name: 'test_package', project: project) }

  context '#branch' do
    let(:branch_package) { BranchPackage.new(project: project.name, package: package.name) }
    let!(:update_project) { create(:project, name: 'BaseDistro:Update') }
    let!(:update_project_attrib) { create(:update_project_attrib, project: project, update_project: update_project) }
    let(:leap_project) { create(:project, name: 'openSUSE_Leap') }
    let(:apache) { create(:package, name: 'apache2', project: leap_project) }
    let(:branch_apache_package) { BranchPackage.new(project: leap_project.name, package: apache.name) }

    before(:each) do
      User.current = user
    end

    after(:each) do
      Project.where('name LIKE ?', "#{user.home_project}:branches:%").destroy_all
    end

    context 'package with UpdateProject attribute' do
      it 'should increase Package by one' do
        expect { branch_package.branch }.to change{ Package.count }.by(1)
      end

      it 'should create home:tom:branches:BaseDistro:Update project' do
        branch_package.branch
        expect(Project.where(name: "#{home_project.name}:branches:BaseDistro:Update")).to exist
      end
    end

    context 'project with ImageTemplates attribute' do
      let(:attribute_type) { AttribType.find_by_namespace_and_name!('OBS', 'ImageTemplates') }
      let(:leap_project) { create(:project, name: 'openSUSE_Leap') }
      let(:apache) { create(:package, name: 'apache2', project: leap_project) }
      let!(:image_templates_attrib) { create(:attrib, attrib_type: attribute_type, project: leap_project) }
      let(:branch_package) { BranchPackage.new(project: leap_project.name, package: apache.name) }

      context 'auto cleanup attribute' do
        it 'is set to 14 if there is no default' do
          branch_apache_package.branch
          project = Project.find_by_name(user.branch_project_name("openSUSE_Leap"))
          expect(14.days.from_now - Time.zone.parse(project.attribs.first.values.first.value)).to be < 1.minute
        end

        it 'is set to the default' do
          allow(Configuration).to receive(:cleanup_after_days).and_return(42)
          branch_apache_package.branch
          project = Project.find_by_name(user.branch_project_name("openSUSE_Leap"))
          expect(42.days.from_now - Time.zone.parse(project.attribs.first.values.first.value)).to be < 1.minute
        end
      end

      context 'publish flag' do
        it 'is disabled' do
          allow(Configuration).to receive(:disable_publish_for_branches).and_return(false)
          branch_package.branch
          project = Project.find_by_name(user.branch_project_name("openSUSE_Leap"))
          expect(project.flags.where(status: "disable", flag: "publish")).to exist
        end
      end
    end

    context 'project without ImageTemplates attribute' do
      context 'auto cleanup attribute' do
        it 'is set to the default' do
          allow(Configuration).to receive(:cleanup_after_days).and_return(42)
          branch_apache_package.branch
          project = Project.find_by_name(user.branch_project_name("openSUSE_Leap"))
          expect(42.days.from_now - Time.zone.parse(project.attribs.first.values.first.value)).to be < 1.minute
        end

        it 'is not set' do
          branch_apache_package.branch
          project = Project.find_by_name(user.branch_project_name("openSUSE_Leap"))
          expect(project.attribs.length).to be(0)
        end
      end

      context 'publish flag' do
        it 'is disabled when Configuration.disable_publish_for_branches is false' do
          allow(Configuration).to receive(:disable_publish_for_branches).and_return(false)
          branch_apache_package.branch
          project = Project.find_by_name(user.branch_project_name("openSUSE_Leap"))
          expect(project.flags.where(status: "disable", flag: "publish")).to_not exist
        end

        it 'is enabled by default' do
          branch_apache_package.branch
          project = Project.find_by_name(user.branch_project_name("openSUSE_Leap"))
          expect(project.flags.where(status: "disable", flag: "publish")).to exist
        end
      end
    end
  end
end
