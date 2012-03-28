require 'selenium/client'

class TC80__Spider < TestCase

  def getlinks
    baseuri = URI.parse(@driver.current_url)
    @driver.find_elements(:tag_name => "a").each do |element|
      next unless element.displayed?
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
    puts "Found #{message} on #{url}, crawling path"
    indent = ' '
    while @pages_visited.has_key? url
      url, text = @pages_visited[url]
      puts "#{indent}#{url} ('#{text}')"
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
        puts "crawled #{theone}"
        @wait.until { 
          @driver.execute_script('return jQuery.active') == 0
        }
        unless @driver.find_elements(:css => "div#flash-messages div.ui-state-error").empty?
          raiseit("flash alert", theone) 
        end
        unless @driver.find_elements(:css => "#exception-error").empty?
          raiseit("error", theone)
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

    @wait = Selenium::WebDriver::Wait.new(:timeout => 6, :interval => 0.1)
    @port = URI.parse( $data[:url] ).port
    @driver = $page.driver
    @driver.navigate.to($data[:url])
    getlinks
    crawl
    
  end

end
