require 'rails_helper'

RSpec.describe Relationship do
  before(:all) do
    @caching_state = ActionController::Base.perform_caching
    ActionController::Base.perform_caching = true
  end

  after(:all) do
    ActionController::Base.perform_caching = @caching_state
  end

  it '.add_user' do
    skip
  end

  it '.add_group' do
    skip
  end

  describe '.forbidden_project_ids' do
    let(:confirmed_user) { create(:confirmed_user) }
    let(:project) { create(:forbidden_project) }

    context 'for admins' do
      let(:admin_user) { create(:admin_user) }

      before do
        login(admin_user)
      end

      it { expect(Relationship.forbidden_project_ids).to eq([0]) }
    end

    context 'for users' do
      let(:confirmed_user2) { create(:confirmed_user) }

      before do
        login(confirmed_user)
        create(:relationship_project_user, project: project, user: confirmed_user)
        login(confirmed_user2)
      end

      it { expect(Relationship.forbidden_project_ids).to include(project.id) }
    end

    context 'for whitelisted users' do
      before do
        login(confirmed_user)
        create(:relationship_project_user, project: project, user: confirmed_user)
      end

      it { expect(Relationship.forbidden_project_ids).not_to include(project.id) }
    end
  end

  it '.discard_cache' do
    skip
  end
end
