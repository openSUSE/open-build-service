# encoding: utf-8

require 'test_helper'

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
      fill_in 'name', with: new_project[:name]
    end

    new_project[:description].squeeze!(' ')
    new_project[:description].gsub!(/ *\n +/, "\n")
    new_project[:description].strip!
    message_prefix = "Project '#{new_project[:namespace] + new_project[:name]}' "

    fill_in 'title', with: new_project[:title]
    fill_in 'description', with: new_project[:description]
    find(:id, 'maintenance_project').click if new_project[:maintenance]
    find(:id, 'access_protection').click if new_project[:access_protection]
    click_button('Create Project')

    if new_project[:expect] == :success
      flash_message.must_equal message_prefix + 'was created successfully'
      flash_message_type.must_equal :info

      new_project[:description] = 'No description set' if new_project[:description].empty?
      assert_equal new_project[:description].gsub(%r{\s+}, ' '), project_description
    elsif new_project[:expect] == :invalid_name
      flash_message.must_equal "Invalid project name '#{new_project[:name]}'."
      flash_message_type.must_equal :alert
    elsif new_project[:expect] == :no_permission
      permission_error = 'You lack the permission to create '
      permission_error += "the project '#{new_project[:namespace] + new_project[:name]}'. "
      permission_error += "Please create it in your home:#{current_user} namespace"
      flash_message.must_equal permission_error
      flash_message_type.must_equal :alert
    elsif new_project[:expect] == :already_exists
      flash_message.must_equal message_prefix + 'already exists.'
      flash_message_type.must_equal :alert
    else
      throw 'Invalid value for argument <expect>.'
    end
  end


  def open_create_subproject(opts)
    visit webui_engine.project_subprojects_path(project: opts[:project])
    click_link('link-create-subproject')
    page.must_have_text 'Create New Subproject'
  end


  test 'create_home_project_for_user' do

    login_user('user1', '123456')
    visit webui_engine.root_path
    open_new_project_from_main
    assert creating_home_project?
    create_project(title: 'HomeProject Title', namespace: 'home:',
                   description: 'Test generated empty home project.')
  end


  test 'create_home_project_for_second_user' do

    login_user('user2', '123456')
    visit webui_engine.root_path

    open_new_project_from_main
    assert creating_home_project?
    create_project(title: 'HomeProject Title',
                   namespace: 'home:',
                   description: 'Test generated empty home project for second user.')
  end


  test 'create_subproject_for_user' do

    login_Iggy
    open_create_subproject(project: 'home:Iggy')
    create_project(
        name: 'SubProject1',
        namespace: 'home:Iggy:',
        title: 'SubProject1 Title',
        description: 'Test generated empty subproject.')

    open_create_subproject(project: 'home:Iggy')
    create_project(
        name: 'SubProject1',
        namespace: 'home:Iggy:',
        title: 'NewTitle' + Time.now.to_i.to_s,
        description: 'Empty subproject with duplicated name. Should give error!',
        expect: :already_exists)

  end


  test 'create_subproject_without_name' do

    login_Iggy
    open_create_subproject(project: 'home:Iggy')
    create_project(
        name: '',
        title: 'NewTitle' + Time.now.to_i.to_s,
        description: 'Test generated empty project without name. Should give error!',
        expect: :invalid_name)
  end


  test 'create_subproject_name_with_spaces' do
    login_Iggy

    open_create_subproject(project: 'home:Iggy')
    create_project(
        name: 'project name with spaces',
        title: 'NewTitle' + Time.now.to_i.to_s,
        description: 'Test generated empty project without name. Should give error!',
        expect: :invalid_name)
  end


  test 'create_subproject_with_only_name' do

    login_Iggy

    open_create_subproject(project: 'home:Iggy')
    create_project(
        name: 'SubProject2',
        title: '',
        namespace: 'home:Iggy:',
        description: '')
  end


  test 'create_subproject_with_long_description' do

    login_Iggy

    open_create_subproject(project: 'home:Iggy')
    create_project(
        name: 'SubProject3',
        title: 'Subproject with long text',
        namespace: 'home:Iggy:',
        description: LONG_DESCRIPTION)
  end


  test 'create_global_project' do

    login_king to: webui_engine.project_list_all_path

    click_link('Create new project')
    create_project(
        name: 'PublicProject1',
        title: 'NewTitle' + Time.now.to_i.to_s,
        description: "Test generated empty public project by #{current_user}.")
  end


  test 'create_global_project_as_user' do

    login_Iggy to: webui_engine.project_list_all_path

    click_link('Create new project')
    create_project(
        name: 'PublicProj-' + Time.now.to_i.to_s,
        title: 'NewTitle' + Time.now.to_i.to_s,
        description: 'Test generated empty public project by user. Should give error.',
        expect: :no_permission)
  end

  test "first case of issue 204" do
    login_king to: webui_engine.project_new_path

    prjroot = Faker::Lorem.characters(20)
    create_project(
        name: prjroot,
        title: 'none',
        description: 'none')

    visit webui_engine.project_subprojects_path project: prjroot
    click_link 'Create subproject'

    fill_in :name, with: 'b'
    click_button 'Create Project'

    # the parent project should be clickable
    within '#breadcrump' do
      find(:link, prjroot).text.must_equal prjroot
    end
  end

  test "second case of issue 204" do
    prjroot = Faker::Lorem.characters(20)
    subproject = prjroot + ':b'

    login_king to: webui_engine.project_new_path

    fill_in :name, with: subproject
    click_button 'Create Project'

    # now create the parent project
    visit webui_engine.project_new_path
    fill_in :name, with: prjroot
    click_button 'Create Project'

    visit webui_engine.project_show_path project: subproject
    # the parent project should be clickable
    within '#breadcrump' do
      find(:link, prjroot).text.must_equal prjroot
    end
  end

  # RUBY CODE ENDS HERE.
  # BELOW ARE APPENDED ALL DATA STRUCTURES USED BY THE TESTS.


  # -------------------------------------------------------------------------------------- #
  LONG_DESCRIPTION = <<LICENSE_END
This
is äüß
a very
long
text
that
will
break
into
many 
many
lines.

Way / 
more
than
what
might
be
reasonable
so
the
lines
are folded
away
by
default.
LICENSE_END
# -------------------------------------------------------------------------------------- #


end
