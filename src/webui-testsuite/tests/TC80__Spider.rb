class TC80__Spider < TestCase

  def getlinks
    @driver.find_elements(:tag_name => "a").each do |link|
      link = link.attribute("href")
      next unless link =~ %r{^http://localhost:};
      unless @pages_visited.has_key? link
        @pages_to_visit[link] ||= @driver.current_url
      end
    end
  end

  def crawl
    while @pages_to_visit.length > 0
      theone = @pages_to_visit.keys.sort.first
      wherefrom = @pages_to_visit[theone]
      @pages_to_visit.delete theone
      @pages_visited[theone] = 1
      puts "crawl #{theone}"
      begin
        @driver.get(theone)
      rescue Timeout::Error
        next
      end
      getlinks
    end
  end

  test :spider_anonymously do
    @pages_to_visit = Hash.new
    @pages_visited = Hash.new

    @driver = $page.driver
    @driver.navigate.to($data[:url])
    getlinks
    crawl
    
  end

end
