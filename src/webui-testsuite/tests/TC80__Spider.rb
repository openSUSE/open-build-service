require 'selenium/client'

class TC80__Spider < TestCase

  def getlinks
    baseuri = URI.parse(@driver.current_url)
    @driver.find_elements(:tag_name => "a").each do |element|
      next unless element.displayed?
      next if element.attribute("data-remote")
      link = element.attribute("href")
      begin
        link = baseuri.merge(link)
      rescue ArgumentError 
        # if merge does not like it, it's not a valid link
        next
      end
      link.fragment = nil
      link.normalize!
      next unless link.host == 'localhost'
      next unless link.port == @port
      unless @pages_visited.has_key? link.to_s
        @pages_to_visit[link.to_s] ||= [baseuri.to_s, element.text]
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

  def crawl
    while @pages_to_visit.length > 0
      theone = @pages_to_visit.keys.sort.first
      @pages_visited[theone] = @pages_to_visit[theone]
      @pages_to_visit.delete theone

      begin
        @driver.navigate.to(theone)
        log :info, "crawled #{theone}"
        wait.until { 
          @driver.execute_script('return jQuery.active') == 0
        }
        unless @driver.find_elements(:css => "div#flash-messages div.ui-state-error").empty?
          raiseit("flash alert", theone) 
        end
	foundISE=false
	@driver.find_elements(css: 'h1').each do |h|
          foundISE ||= h.text == 'Internal Server Error'
        end
        if !@driver.find_elements(:css => "#exception-error").empty? || foundISE
          raiseit("error", theone)
          raise "Found error"
        end
      rescue Timeout::Error, Selenium::WebDriver::Error::JavascriptError
        next
      end
      getlinks
    end
  end

  test :spider_anonymously do
    @pages_to_visit = Hash.new
    @pages_visited = Hash.new

    @port = URI.parse( $data[:url] ).port
    @driver = $page.driver
    navigate_to MainPage, user:  :none

    getlinks
    crawl
    
  end

end
