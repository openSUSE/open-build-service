require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class SearchControllerTest < ActionDispatch::IntegrationTest

  def test_search
    visit '/search/search'
    find('#header-logo')

    visit '/search/search?search_text=Base'
    assert page.has_text?(/Base.* distro without update project/)
  end

  def test_disturl_search
    visit '/search/search?search_text=obs://build.opensuse.org/openSUSE:Factory/standard/fd6e76cd402226c76e65438a5e3df693-bash'
    assert find('#flash-messages').has_text? "Project not found: openSUSE:Factory"

    visit '/search/search?search_text=obs://foo'
    assert find('#flash-messages').has_text?(%{obs:// searches are not random})
  end

end
