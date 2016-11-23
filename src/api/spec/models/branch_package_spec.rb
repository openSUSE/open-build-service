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

    before(:each) do
      User.current = user
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
  end
end
