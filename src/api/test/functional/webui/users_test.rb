# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::EditPackageUsersTest < Webui::IntegrationTest
  def test_add_and_edit_package_people # spec/support/shared_examples/features/user_tab.rb
    use_js

    @project = 'kde4'
    @package = 'kdelibs'
    @userspath = package_users_path(project: @project, package: @package)

    login_user 'fred', 'buildservice', to: @userspath

    add_user 'user2', 'maintainer'
    add_user 'user3', 'bugowner'
    add_user 'user4', 'reviewer'
    add_user 'user5', 'downloader'
    add_user 'user6', 'reader'
    add_user 'user6', 'reviewer'
    add_user 'user6', 'downloader'

    add_user 'sadasxsacxsacsa', 'reader', expect: :unknown_user
    add_user '~@$@#%#%@$0-=m,.,\/\/12`;.{{}}{}', 'maintainer', expect: :unknown_user

    # add_package_role_to_username_with_question_sign do
    add_user 'still-buggy?', 'maintainer', expect: :unknown_user

    edit_user name: :user3,
    reviewer: true,
    downloader: true

    edit_user name: :user3,
    reviewer: false,
    downloader: false

    edit_user name: :user6,
    maintainer: false,
    bugowner: false,
    reviewer: false,
    downloader: false,
    reader: false

    edit_user name: :user4,
    maintainer: true,
    bugowner: true,
    reviewer: true,
    downloader: true,
    reader: true

    delete_user :user4
    page.wont_have_selector 'table#user_table tr#user-user4'
  end

  def test_add_and_edit_project_users # spec/support/shared_examples/features/user_tab.rb
    @project = 'kde4'
    @userspath = project_users_path(project: @project)

    login_user 'fred', 'buildservice', to: @userspath

    add_user 'user2', 'maintainer'
    add_user 'user3', 'bugowner'
    add_user 'user4', 'reviewer'
    add_user 'user5', 'downloader'
    add_user 'user6', 'reader'

    add_user 'user6', 'reviewer'
    add_user 'user6', 'downloader'
    add_user 'user6', 'downloader', expect: :already_exists

    add_user 'sadasxsacxsacsa', 'reader', expect: :unknown_user
    add_user '', 'maintainer', expect: :unknown_user
    add_user '~@$@#%#%@$0-=m,.,\/\/12`;.{{}}{}', 'maintainer', expect: :unknown_user
    add_user 'still-buggy?', 'maintainer', expect: :unknown_user

    edit_user name: :user3,
      reviewer: true,
      downloader: true

    edit_user name: :user3,
      reviewer: false,
      downloader: false

    edit_user name: :user6,
      maintainer: false,
      bugowner: false,
      reviewer: false,
      downloader: false,
      reader: false

    edit_user name: :user4,
      maintainer: true,
      bugowner: true,
      reviewer: true,
      downloader: true,
      reader: true
  end

  # Test Helpers

  def edit_role cell, new_value
    unless new_value.nil?
      input = cell.first(:css, 'input')
      input.click unless input.selected? == new_value
    end
  end

  def edit_user options
    assert !options[:name].blank?

    row = find(:css, "tr#user-#{options[:name]}")
    cell = row.all(:css, 'td')

    edit_role cell[1], options[:maintainer]
    edit_role cell[2], options[:bugowner]
    edit_role cell[3], options[:reviewer]
    edit_role cell[4], options[:downloader]
    edit_role cell[5], options[:reader]
  end

  def add_user user, role, options = {}
    find(:id, 'add-user').click

    page.must_have_text %r{Add New User to}
    page.must_have_field 'userid'
    page.must_have_selector 'select#role'

    curl = page.current_url
    options[:expect] ||= :success

    fill_in 'userid', with: user
    find('select#role').select(role)
    click_button('Add user')

    if options[:expect] == :success
      flash_message_type.must_equal :info
      flash_message.must_equal "Added user #{user} with role #{role}"
      assert page.current_url.end_with? @userspath
    elsif options[:expect] == :unknown_user
      flash_message_type.must_equal :alert
      flash_message.must_equal "Couldn't find User with login = #{user}".strip
      assert curl, page.current_url
      # go back manually
      visit @userspath
    elsif options[:expect] == :already_exists
      flash_message_type.must_equal :alert
      flash_message.must_equal 'Relationship already exists'
      visit @userspath
    else
      raise ArgumentError
    end
  end

  def delete_user user
    # overwrite confirm function to avoid the dialog - they are very racy with selenium
    page.evaluate_script('window.confirm = function() { return true; }')
    find(:css, "table#user_table tr#user-#{user} a.remove-user").click
    flash_message_type.must_equal :info
    flash_message.must_equal "Removed user #{user}"
  end
end
