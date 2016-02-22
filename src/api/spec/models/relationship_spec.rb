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
    it 'always returns 0 for admins' do
      User.current = create(:admin_user)

      expect(Relationship.forbidden_project_ids).to eq([0])
    end

    it 'hides projects for users' do
      User.current = create(:confirmed_user)
      project = create(:forbidden_project)
      create(:relationship, project: project, user: User.current)

      User.current = create(:confirmed_user)
      expect(Relationship.forbidden_project_ids).to include(project.id)
    end

    it 'shows projects for whitelisted users' do
      project = create(:forbidden_project)
      user = create(:confirmed_user)
      create(:relationship, project: project, user: user)

      User.current = user
      expect(Relationship.forbidden_project_ids).not_to include(project.id)
    end
  end

  it '.discard_cache' do
    skip
  end
end
