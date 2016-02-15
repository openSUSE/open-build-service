require "rails_helper"

RSpec.describe User do
  it "creates a home project by default if allow_user_to_create_home_project is enabled" do
    Configuration.stubs(:allow_user_to_create_home_project).returns(true)
    user = create(:confirmed_user)
    project = Project.find_by(name: user.home_project_name)
    expect(project).not_to be_nil
  end

  it "doesn't creates a home project if allow_user_to_create_home_project is disabled" do
    Configuration.stubs(:allow_user_to_create_home_project).returns(false)
    user = create(:confirmed_user)
    project = Project.find_by(name: user.home_project_name)
    expect(project).to be_nil
  end
end
