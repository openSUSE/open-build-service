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

  # ============================================================================
  # Returns the description of the viewed project as is displayed.
  # Caller should keep in mind that multi-space / multi-line text
  # will probably get trimmed and stripped when displayed.
  #
  def project_description
    find(:id, 'description_text').text
  end

  def open_new_project_from_main
    find(:css, '#proceed-document-new .proceed_text a').click
    page.must_have_text 'Project Name:'
  end

  def creating_home_project?
    return page.has_text? "Your home project doesn't exist yet. You can create it now"
  end

  def create_project new_project
    new_project[:expect] ||= :success
    new_project[:title] ||= ''
    new_project[:description] ||= ''
    new_project[:maintenance] ||= false
    new_project[:hidden] ||= false
    new_project[:namespace] ||= ''

    if creating_home_project?
      new_project[:name] ||= current_user
      current_user.must_equal new_project[:name]
    else
      new_project[:name] ||= ''
      fill_in 'project_name', with: new_project[:name]
    end

    new_project[:description].squeeze!(' ')
    new_project[:description].gsub!(/ *\n +/, "\n")
    new_project[:description].strip!

    fill_in 'project_title', with: new_project[:title]
    fill_in 'project_description', with: new_project[:description]
    find(:id, 'maintenance_project').click if new_project[:maintenance]
    find(:id, 'access_protection').click if new_project[:access_protection]
    click_button('Create Project')

    if new_project[:expect] == :success
      flash_message.must_equal "Project '#{new_project[:namespace] + new_project[:name]}' was created successfully"
      flash_message_type.must_equal :info

      new_project[:description] = 'No description set' if new_project[:description].empty?
      assert_equal new_project[:description].gsub(%r{\s+}, ' '), project_description
    elsif new_project[:expect] == :invalid_name
      flash_message.must_equal "Failed to save project '#{new_project[:namespace] + new_project[:name]}'. Name is illegal."
      flash_message_type.must_equal :alert
    elsif new_project[:expect] == :no_permission
      flash_message.must_equal "Sorry you're not allowed to create this Project"
      flash_message_type.must_equal :alert
    elsif new_project[:expect] == :already_exists
      flash_message.must_equal "Failed to save project '#{new_project[:namespace] + new_project[:name]}'. Name has already been taken."
      flash_message_type.must_equal :alert
    else
      throw 'Invalid value for argument <expect>.'
    end
  end


  def open_create_subproject(opts)
    visit project_subprojects_path(project: opts[:project])
    click_link('link-create-subproject')
    page.must_have_text 'Create New Subproject'
  end


  def test_create_home_project_for_user

    login_user('user1', '123456')
    visit root_path
    open_new_project_from_main
    assert creating_home_project?
    create_project(title: 'HomeProject Title', namespace: 'home:',
                   description: 'Test generated empty home project.')
  end


  def test_create_home_project_for_second_user

    login_user('user2', '123456')
    visit root_path

    open_new_project_from_main
    assert creating_home_project?
    create_project(title: 'HomeProject Title',
                   namespace: 'home:',
                   description: 'Test generated empty home project for second user.')
  end

  def test_create_global_project

    login_king to: project_list_all_path

    click_link('Create new project')
    create_project(
        name: 'PublicProject1',
        title: 'NewTitle' + Time.now.to_i.to_s,
        description: "Test generated empty public project by #{current_user}.")
  end


  def test_create_global_project_as_user

    login_Iggy to: project_list_all_path

    click_link('Create new project')
    create_project(
        name: 'PublicProj-' + Time.now.to_i.to_s,
        title: 'NewTitle' + Time.now.to_i.to_s,
        description: 'Test generated empty public project by user. Should give error.',
        expect: :no_permission)
  end

  def test_first_case_of_issue_204
    login_king to: new_project_path

    prjroot = Faker::Lorem.characters(20)
    create_project(
        name: prjroot,
        title: 'none',
        description: 'none')

    visit project_subprojects_path project: prjroot
    click_link 'Create subproject'

    fill_in :project_name, with: 'b'
    click_button 'Create Project'

    # the parent project should be clickable
    within '#breadcrump' do
      find(:link, prjroot).text.must_equal prjroot
    end
  end

  def test_second_case_of_issue_204
    prjroot = Faker::Lorem.characters(20)
    subproject = prjroot + ':b'

    login_king to: new_project_path

    fill_in :project_name, with: subproject
    click_button 'Create Project'

    # now create the parent project
    visit new_project_path
    fill_in :project_name, with: prjroot
    click_button 'Create Project'

    visit project_show_path project: subproject
    # the parent project should be clickable
    within '#breadcrump' do
      find(:link, prjroot).text.must_equal prjroot
    end
  end
end
