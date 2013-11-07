require 'test_helper'

class Webui::WatchlistTest < Webui::IntegrationTest

  test 'watchlists' do
    use_js
    login_tom to: webui_engine.project_show_path(project: 'BaseDistro')

    # assert watchlist is empty
    page.execute_script("$('#menu-favorites').show();")
    all(:css, 'span.icons-project').count.must_equal 0

    page.execute_script("$('#menu-favorites').show();")
    
    find(:css, '#menu-favorites').must_have_text %r{Add this project to Watchlist}
    find(:css, '#toggle_watch > span.desc').click
    Timecop.travel 1
    page.execute_script("$('#menu-favorites').show();")

    find(:css, '#menu-favorites span.project-link').text.must_equal 'BaseDistro'
    find(:css, '#menu-favorites').must_have_text %r{Remove this project from Watchlist}
    find(:css, '#toggle_watch > span.desc').click

    Timecop.travel 1

    page.execute_script("$('#menu-favorites').show();")
    find(:css, '#menu-favorites').must_have_text %r{Add this project to Watchlist}
    find(:css, '#toggle_watch > span.desc').click

    Timecop.travel 1

    visit webui_engine.project_show_path(project: 'My:Maintenance')

    page.execute_script("$('#menu-favorites').show();")
    find(:css, '#menu-favorites').must_have_text %r{Add this project to Watchlist}
    find(:css, '#toggle_watch > span.desc').click

    Timecop.travel 1

    page.execute_script("$('#menu-favorites').show();")
    first(:css, 'span.icons-project').click

    find(:css, '#project_title').must_have_text %r{This is a base distro}
    # teardown
    page.execute_script("$('#menu-favorites').show();")
    find(:css, '#toggle_watch > span.desc').click
    Timecop.freeze 1
    page.execute_script("$('#menu-favorites').show();")
    within('#menu-favorites') do
      find(:link, 'My:Maintenance').click
    end
    page.execute_script("$('#menu-favorites').show();")
    find(:css, '#toggle_watch > span.desc').click
    all(:css, 'span.icons-project').count.must_equal 0
  end

end
