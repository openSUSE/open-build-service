# encoding: utf-8
require_relative '../../test_helper'

class Webui::ProjectLockTest < Webui::IntegrationTest
  fixtures :all
  uses_transaction :test_project_unlock
  uses_transaction :test_project_unlock_fails

  def test_project_unlock # spec/features/webui/projects_spec.rb
    use_js
    login_user('user6', 'buildservice')
    visit project_show_path(project: 'home:user6')
    click_link('Unlock project')
    fill_in 'comment', with: 'Freedom at last!'
    click_button('Ok')
    find('#flash-messages').must_have_text "Successfully unlocked project"
  end

  def test_project_unlock_fails # spec/features/webui/projects_spec.rb
    Project.any_instance.stubs(:can_be_unlocked?).returns(false)
    use_js
    login_user('user6', 'buildservice')
    visit project_show_path(project: 'home:user6')
    click_link('Unlock project')
    click_button('Ok')
    find('#flash-messages').must_have_text "Project can't be unlocked"
  end
end
