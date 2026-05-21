require_relative '../../test_helper'

require 'benchmark'
require 'nokogiri'

class Webui::SpiderTest < Webui::IntegrationTest
  def ignore_link?(link)
    return true if link.include?('/mini-profiler-resources')
    # that link is just a top ref
    return true if link.include?('/package/rdiff')
    # admin can see even the hidden
    return true if link.end_with?('/package/show/HiddenRemoteInstance')
    return true if link.include?('/package/show/SourceprotectedProject')
    # this is crashing (bug)
    return true if link.include?('/package/show/UseRemoteInstance')
    return true if link.end_with?('/project/show/HiddenRemoteInstance')
    return true if link.end_with?('/project/show/RemoteInstance')
    return true if link.end_with?('/package/show/BaseDistro3/pack2')
    return true if link.end_with?('/project/show/BaseDistro3')
    return true if link.end_with?('/package/show/home:Iggy/TestPack')
    return true if link.end_with?('/package/show/home:Iggy/ToBeDeletedTestPack')
    return true if link.end_with?('/project/show/home:Iggy')
    return true if link.end_with?('/project/show/home:user6')
    return true if link.include?('/live_build_log/BinaryprotectedProject')
    return true if link.include?('/live_build_log/SourceprotectedProject')
    return true if link.include?('/live_build_log/home:Iggy/ToBeDeletedTestPack')
    return true if link.include?('/live_build_log')
    # we do not really serve binary packages in the test environment
    return true if %r{/projects/.*/packages/.*/repositories/.*/binaries/.*/.*}.match?(link)
    # apidocs is not configured in test environment
    return true if link.end_with?('/apidocs/index')

    # no need to visit flipper
    true if link.end_with?('/flipper')
  end

  def getlinks(baseuri, body)
    # skip some uninteresting projects
    return if baseuri.include?('project=home%3Afred')
    return if baseuri.include?('project=home%3Acoolo')
    return if baseuri.include?('project=deleted')

    baseuri = URI.parse(baseuri)

    links_added = 0
    body.traverse do |tag|
      next unless tag.element?
      next unless tag.name == 'a'
      next if tag.attributes['data-remote']
      next if tag.attributes['data-method']

      link = tag.attributes['href']
      begin
        link = baseuri.merge(link)
      rescue ArgumentError
        # if merge does not like it, it's not a valid link
        next
      end
      link.fragment = nil
      link.normalize!
      next unless link.host == baseuri.host
      next unless link.port == baseuri.port

      link = link.to_s
      next if ignore_link?(link)
      next if tag.content == 'show latest'
      next if @pages_visited.key?(link)
      next if @pages_to_visit.key?(link)

      links_added += 1
      @pages_to_visit[link] = [baseuri.to_s, tag.content]
    end
    puts "Added #{links_added} more links to the pages to visit..." if links_added.positive?
  end

  def raiseit(message, url)
    # known issues
    return if url.include?('/source/')

    warn "Found #{message} on #{url}, crawling path"
    indent = ' '
    while @pages_visited.key?(url)
      url, text = @pages_visited[url]
      break if url.blank?

      warn "#{indent}#{url} ('#{text}')"
      indent += '  '
    end
    raise "Found #{message}"
  end

  def crawl
    load_sitemap('/sitemaps')
    until @pages_to_visit.empty?
      theone = @pages_to_visit.keys.min
      @pages_visited[theone] = @pages_to_visit[theone]
      @pages_to_visit.delete theone

      begin
        puts "(#{@pages_to_visit.length} of #{@pages_visited.keys.length + @pages_to_visit.length}) Crawling #{theone}"
        page.visit(theone)
        if page.status_code != 200
          raiseit("Status code #{page.status_code}", theone)
          return
        end
        unless page.response_headers['Content-Type'].include?('text/html')
          # puts "ignoring #{page.response_headers.inspect}"
          next
        end

        page.first('.navbar-brand')
      rescue Timeout::Error
        next
      rescue ActionController::RoutingError
        raiseit('routing error', theone)
        return
      end
      body = nil
      begin
        body = Nokogiri::HTML4::Document.parse(page.source).root
      rescue Nokogiri::XML::SyntaxError
        # puts "HARDCORE!! #{theone}"
      end
      next unless body

      flashes = body.css('div#flash div.alert-error')
      raiseit("flash alert #{flashes.first.content.strip}", theone) unless flashes.empty?
      body.css('h1').each do |h|
        raiseit('Internal Server Error', theone) if h.content == 'Internal Server Error'
      end
      body.css('h2').each do |h|
        raiseit('XML errors', theone) if h.content == 'XML errors'
      end
      body.css('#exception-error').each do |e|
        raiseit("error '#{e.content}'", theone)
      end
      getlinks(theone, body)
    end
  end

  def load_sitemap(url)
    page.visit(url)
    return unless page.status_code == 200

    r = Xmlhash.parse(page.source)
    r.elements('sitemap') do |s|
      load_sitemap(s['loc'])
    end
    r.elements('url') do |s|
      next if ignore_link?(s['loc'])

      @pages_to_visit[s['loc']] = [url, 'sitemap']
    end
  end

  def setup
    Backend::Test.start(wait_for_scheduler: true)
  end

  def test_spider_anonymously
    visit root_path
    @pages_to_visit = { page.current_url => [nil, nil] }
    @pages_visited = {}

    crawl
    ActiveRecord::Base.connection_handler.clear_active_connections!

    assert_operator(@pages_visited.keys.length, :>, 800)
  end

  def test_spider_as_admin
    login_king(to: root_path)
    @pages_to_visit = { page.current_url => [nil, nil] }
    @pages_visited = {}

    crawl
    ActiveRecord::Base.connection_handler.clear_active_connections!

    assert_operator(@pages_visited.keys.length, :>, 1200)
  end
end
