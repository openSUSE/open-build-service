RSpec.describe BsRequestCleanTasksCacheJob do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:target_project) { create(:project, name: 'target_project') }
    let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
    let(:target_package) { create(:package, name: 'target_package', project: target_project) }
    let(:source_package) { create(:package, name: 'source_package', project: source_project) }
    let(:submit_request) do
      create(:bs_request_with_submit_action,
             target_package: target_package,
             source_package: source_package)
    end

    context 'creator of bs_request' do
      let!(:request) { create(:set_bugowner_request, creator: user) }
      let!(:cache_key) { user.cache_key_with_version }
      let(:user) { create(:admin_user) }

      before { BsRequestCleanTasksCacheJob.new.perform(request.id) }

      it { expect(user.reload.cache_key_with_version).not_to eq(cache_key) }
    end

    context 'direct maintainer of a target_project' do
      let(:target_project) { create(:project) }
      let!(:request) do
        create(:bs_request_with_submit_action,
               target_project: target_project,
               source_package: source_package)
      end
      let!(:relationship_project_user) { create(:relationship_project_user, project: target_project) }
      let!(:cache_key) { user.cache_key_with_version }
      let(:user) { relationship_project_user.user }

      before { BsRequestCleanTasksCacheJob.new.perform(request.id) }

      it { expect(user.reload.cache_key_with_version).not_to eq(cache_key) }
    end

    context 'group maintainer of a target_project' do
      let(:target_project) { create(:project) }

      let!(:request) do
        create(:bs_request_with_submit_action,
               target_project: target_project,
               source_package: source_package)
      end

      let(:relationship_project_group) { create(:relationship_project_group, project: target_project) }
      let(:group) { relationship_project_group.group }
      let!(:groups_user) { create(:groups_user, group: group) }
      let!(:cache_key) { user.cache_key_with_version }
      let(:user) { groups_user.user }

      before { BsRequestCleanTasksCacheJob.new.perform(request.id) }

      it { expect(user.reload.cache_key_with_version).not_to eq(cache_key) }
    end

    context 'direct maintainer of a target_package' do
      let!(:request) { submit_request }
      let!(:relationship_package_user) { create(:relationship_package_user, package: target_package) }
      let!(:cache_key) { user.cache_key_with_version }
      let(:user) { relationship_package_user.user }

      before { BsRequestCleanTasksCacheJob.new.perform(request.id) }

      it { expect(user.reload.cache_key_with_version).not_to eq(cache_key) }
    end

    context 'group maintainer of a target_package' do
      let!(:request) { submit_request }
      let(:relationship_package_group) { create(:relationship_package_group, package: target_package) }
      let(:group) { relationship_package_group.group }
      let!(:groups_user) { create(:groups_user, group: group) }
      let!(:cache_key) { user.cache_key_with_version }
      let(:user) { groups_user.user }

      before { BsRequestCleanTasksCacheJob.new.perform(request.id) }

      it { expect(user.reload.cache_key_with_version).not_to eq(cache_key) }
    end
  end
end
