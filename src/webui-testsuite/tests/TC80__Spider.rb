require 'selenium/client'
require 'benchmark'
require 'nokogiri'

class TC80__Spider < TestCase

  def getlinks(baseuri, body)
    baseuri = URI.parse(baseuri)

    body.traverse do |tag|
      next unless tag.element? 
      next unless tag.name == 'a'
      next if tag.attributes['data-remote']
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
      next if link =~ %r{/mini-profiler-resources}
      unless @pages_visited.has_key? link
        @pages_to_visit[link] ||= [baseuri.to_s, tag.content]
      end
    end
  end

  def raiseit(message, url)
    # known issues
    return if url.end_with? "/package/view_file?file=my_file&package=pack2&project=BaseDistro%3AUpdate&rev=1"
    return if url.end_with? "/package/view_file?file=my_file&package=pack2&project=Devel%3ABaseDistro%3AUpdate&rev=1"
    return if url.end_with? "/package/view_file?file=my_file&package=pack3&project=Devel%3ABaseDistro%3AUpdate&rev=1"
    return if url.end_with? "/package/rdiff"
    return if url.end_with? "/package/view_file?file=myfile&package=pack2_linked&project=BaseDistro2.0&rev=1"
    return if url.end_with? "/package/view_file?file=package.spec&package=pack2_linked&project=BaseDistro2.0&rev=1"
    return if url.end_with? "/package/view_file?file=myfile&package=pack2_linked&project=BaseDistro2.0%3ALinkedUpdateProject&rev=1"
    return if url.end_with? "/package/view_file?file=package.spec&package=pack2_linked&project=BaseDistro2.0%3ALinkedUpdateProject&rev=1"
    return if url =~ %r{/package/binary\?.*project=BinaryprotectedProject}
    return if url.end_with? "/package/show?package=notthere&project=NotExisiting"
    return if url.end_with? "/package/view_file?file=my_file&package=remotepackage&project=LocalProject&rev=1"
    return if url.end_with? "/project/show?project=HiddenRemoteInstance"
    return if url.end_with? "/project/show?project=HiddenProject"
    return if url.end_with? "/project/show?project=NotExisiting"
    return if url.end_with? "/package/files?package=target&project=SourceprotectedProject"
    return if url =~ %r{/package/binary\?.*project=BinaryprotectedProject}
    return if url.end_with? "/package/revisions?package=pack&project=SourceprotectedProject"
    return if url.end_with? "/package/users?package=pack&project=SourceprotectedProject"

    log :error, "Found #{message} on #{url}, crawling path"
    indent = ' '
    while @pages_visited.has_key? url
      url, text = @pages_visited[url]
      log :error, "#{indent}#{url} ('#{text}')"
      indent += '  '
    end
    #raise "Found #{message}"
  end

  def crawl(driver)
    while @pages_to_visit.length > 0
      theone = @pages_to_visit.keys.sort.first
      @pages_visited[theone] = @pages_to_visit[theone]
      @pages_to_visit.delete theone

      navtime = Benchmark.realtime do 
        begin
          driver.navigate.to(theone)
          log :info, "crawled #{theone}"
          wait.until { 
            driver.execute_script('return jQuery.active') == 0
          }
        rescue Timeout::Error, Selenium::WebDriver::Error::JavascriptError
          next
        end
      end
      body = nil
      begin
        body = Nokogiri::XML::Document.parse(driver.page_source, nil, nil, Nokogiri::XML::ParseOptions::STRICT).root
      rescue Nokogiri::XML::SyntaxError
        puts "HARDCORE!! #{baseuri}"
        next
      end
      if !body.css("div#flash-messages div.ui-state-error").empty?
        raiseit("flash alert", theone) 
      end
      body.css('h1').each do |h|
        if h.content == 'Internal Server Error'
          raiseit("Internal Server Error", theone)
        end
      end
      body.css("#exception-error").each do |e|
        raiseit("error '#{e.content}'", theone)
        raise "Found error"
      end
      getlinks(theone, body)
      #puts "#{Time.now} #{theone} #{navtime}"
    end
  end

  test :spider_anonymously do
    url = $data[:url]
    @pages_to_visit = { url => [nil, nil] }
    @pages_visited = Hash.new

    crawl($page.driver)
    
  end

end
