require 'rails_helper'

RSpec.describe BranchPackage::SetTargetProject, vcr: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_project) { user.home_project }
  let!(:project) { create(:project, name: 'BaseDistro') }
  let!(:package) { create(:package, name: 'test_package', project: project) }

  before do
    login user
  end

  describe '.new' do
    it { expect(BranchPackage::SetTargetProject.new({})).not_to be_nil }
  end

  describe '#target_project' do
    context 'when target_project is provided' do
      let(:set_target_project) { BranchPackage::SetTargetProject.new(target_project: project.name) }

      it { expect(set_target_project.target_project).to eq(project.name) }
    end

    context 'when request is provided' do
      let(:bs_request) do
        create(:bs_request_with_submit_action, creator: user, target_package: package,
                                               source_package: package)
      end
      let(:set_target_project) { BranchPackage::SetTargetProject.new(request: bs_request.number) }

      it { expect(set_target_project.target_project).to eq("#{home_project}:branches:REQUEST_#{bs_request.number}") }
    end
  end

  describe '#auto_cleanup' do
    before do
      allow(Configuration).to receive(:cleanup_after_days).and_return(3)
    end

    context 'with target_project and autocleanup' do
      let(:set_target_project) { BranchPackage::SetTargetProject.new(target_project: project.name, autocleanup: 'true') }

      it { expect(set_target_project.auto_cleanup).to eq(3) }
    end
  end

  describe '#valid?' do
    context 'valid name' do
      let(:set_target_project) { BranchPackage::SetTargetProject.new(target_project: project.name, autocleanup: 'true') }

      it { expect(set_target_project).to be_valid }
    end

    context 'invalid name' do
      let(:set_target_project) { BranchPackage::SetTargetProject.new(target_project: '0', autocleanup: 'true') }

      it { expect(set_target_project).not_to be_valid }
    end
  end
end
