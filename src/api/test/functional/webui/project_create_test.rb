# encoding: utf-8

require_relative '../../test_helper'

class Webui::ProjectCreateTest < Webui::IntegrationTest

  uses_transaction :test_create_global_project
  uses_transaction :test_create_home_project_for_second_user
  uses_transaction :test_create_home_project_for_user
  uses_transaction :test_create_subproject_for_user
  uses_transaction :test_create_subproject_with_long_description
  uses_transaction :test_create_subproject_with_only_name
  uses_transaction :test_first_case_of_issue_204
  uses_transaction :test_second_case_of_issue_204

  def test_create_home_project_for_user
    login_user('user1', '123456')
    count = Project.count
    visit new_project_path

    fill_in 'project_name', with: 'home:user1'
    click_button('Create Project')

    assert_equal count + 1, Project.count
  end

  def test_create_global_project
    login_king to: new_project_path
    count = Project.count

    fill_in 'project_name', with: 'PublicProject'
    fill_in 'project_title', with: 'NewTitle'
    click_button('Create Project')

    assert_equal count + 1, Project.count
  end

  def test_create_global_project_as_user
    login_Iggy to: new_project_path
    count = Project.count

    fill_in 'project_name', with: 'PublicProject1'
    fill_in 'project_title', with: 'NewTitle'
    click_button('Create Project')

    assert_equal count, Project.count
    flash_message.must_equal "Sorry you're not allowed to create this Project"
    flash_message_type.must_equal :alert
  end

  def test_breadcrumbs
    login_king to: new_project_path
    count = Project.count

    fill_in 'project_name', with: "my_project"
    fill_in 'project_title', with: 'none'
    click_button('Create Project')

    assert_equal count + 1, Project.count

    visit project_subprojects_path project: "my_project"
    click_link('Create subproject')

    fill_in :project_name, with: 'b'
    click_button('Create Project')

    # the parent project should be clickable
    within '#breadcrump' do
      find(:link, "my_project").text.must_equal "my_project"
    end
  end

  def test_breadcrumps_with_subproject_first
    login_king to: new_project_path
    count = Project.count

    fill_in 'project_name', with: "my_other_project:sub"
    click_button('Create Project')

    assert_equal count + 1, Project.count

    visit new_project_path
    fill_in :project_name, with: "my_other_project"
    click_button 'Create Project'

    assert_equal count + 2, Project.count

    visit project_show_path project: "my_other_project:sub"

    # the parent project should be clickable
    within '#breadcrump' do
      find(:link, "my_other_project").text.must_equal "my_other_project"
    end
  end
end
