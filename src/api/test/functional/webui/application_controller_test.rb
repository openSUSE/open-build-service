require_relative '../../test_helper'

class Webui::ApplicationControllerTest < Webui::IntegrationTest
  include Webui::WebuiHelper

  def setup
    @oldtheme = CONFIG['theme']
  end

  def teardown
    CONFIG['theme'] = @oldtheme
  end

  def test_elide
    d = "don't shorten"
    assert_equal(d, elide(d, d.length))

    t = "Rocking the Open Build Service"
    assert_equal("...the Open Build Service", elide(t, 25, :left))
    assert_equal("R...", elide(t, 4, :right))
    assert_equal("...", elide(t, 3, :right))
    assert_equal("...", elide(t, 2, :right))
    assert_equal("Rocking t... Service", elide(t))
    assert_equal("Rock...ice", elide(t, 10))
    assert_equal("Rock...vice", elide(t, 11))
    assert_equal("Rocking...", elide(t, 10, :right))
  end

  def test_elide_two
    d = "don't shorten"
    t = "Rocking the Open Build Service"

    assert_equal([d, "Rocking the ...uild Service"], elide_two(d, t, 40))
  end

  def test_bento_theme_can_be_configured
    CONFIG['theme'] = 'bento'
    visit root_path
    # without javascript there is no menu but just links
    within '#header' do
      page.must_have_selector '#item-downloads'
    end

    visit package_show_path(project: 'home:Iggy', package: 'TestPack')
    assert page.has_no_link?('Download package')

    CONFIG['software_opensuse_url'] = "http://software.opensuse.org"

    visit package_show_path(project: 'home:Iggy', package: 'TestPack')
    page.must_have_link 'Download package'
    first(:link, 'Download package')['href'].must_equal 'http://software.opensuse.org/download.html?project=home%3AIggy&package=TestPack'
  end
end
