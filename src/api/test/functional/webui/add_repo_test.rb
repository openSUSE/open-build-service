require_relative '../../test_helper'

class Webui::AddRepoTest < Webui::IntegrationTest
  def test_add_default # spec/features/webui/repositories_spec.rb
    skip "there is a race condition that causes random test failures in the ci we are running inside our rpm build enviroment"
    # [ 1783s]   test_add_default                                               ERROR (117.89s)
    # [ 1783s] Capybara::Poltergeist::StatusFailError:         Capybara::Poltergeist::StatusFailError: Request to
    #   'http://127.0.0.1:43614/user/login' failed to reach server, check DNS and/or server status
    # [ 1783s]             test/test_helper.rb:214:in `login_user'

    use_js
    login_Iggy to: project_show_path(project: 'home:Iggy')

    # actually check there is a link on the project
    click_link 'Repositories'
    page.must_have_text('Repositories of home:Iggy')
    page.must_have_text(/i586, x86_64/)

    click_link 'Add repositories'
    page.must_have_text('Add Repositories to home:Iggy')

    page.must_have_text('KIWI image build')

    check 'repo_Base_repo'
    page.must_have_text("Successfully added repository 'Base_repo'")
    check 'repo_images'
    page.must_have_text('Successfully added image repository')

    visit project_meta_path(project: 'home:Iggy')
    page.must_have_selector('.editor', visible: false)
    xml = Xmlhash.parse(first('.editor', visible: false).value)
    assert_equal([{"name" => "images", "arch" => %w(x86_64 i586) },
                  {"name" => "Base_repo", "path" => {"project" => "BaseDistro2.0", "repository" => "BaseDistro2_repo"},
                   "arch" => %w(i586 x86_64) },
                  {"name" => "10.2", "path" => {"project" => "BaseDistro", "repository" => "BaseDistro_repo"},
                   "arch" => %w(i586 x86_64) }], xml['repository'])
  end
end
