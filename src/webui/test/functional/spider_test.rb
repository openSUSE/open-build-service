module SpiderIntegrator
  
#
# SpiderIntegrator is an includable module for your integration tests
# that will 'spider' over your entire rails application, gathering
# links, ajax requests and forms, following them and ensuring that
# there re no errors or missing pages.
#
# == Installation
# 
#   $ script/plugin install svn://caboo.se/plugins/court3nay/spider_test
#   $ script/generate integration_test spider_test
# 
# == Usage
#
# Load up the test/integration/spider_test.rb and make it look something like this, replacing 
# your own implementation details where appropriate.  You'll probably want to load all of your
# fixtures.
# 
#   require "#{File.dirname(__FILE__)}/../test_helper"
#   
#   class SpiderTest < ActionController::IntegrationTest
#     fixtures :users, :roles, :images, :categories
#     include SpiderIntegrator
#   
#     def test_spider
#       get '/'
#       assert_response :success
#       spider(@response.body, '/', 
#                  :ignore_urls => ['/login', %r{^.+logout}, %r{^.+delete.?}], 
#                  :ignore_forms => [])
#     end
#   
#   end
# 
# If you require a login for your app, you'll need to specifically log in. I do it like:
# 
#   require "#{File.dirname(__FILE__)}/../test_helper"
#   
#   class SpiderTest < ActionController::IntegrationTest
#     fixtures :users, :roles, :images, :categories
#     include SpiderIntegrator
#   
#     def test_spider
#       get '/sessions/new'
#       assert_response :success
#       post '/sessions/create', :login => 'admin', :password => 'test'
#       assert session[:user]
#       assert_response :redirect
#       assert_redirected_to '/'
#       follow_redirect!
#   
#       spider(@response.body, '/', 
#                  :verbose => true,
#                  :ignore_urls => ['/login', %r{^.+logout}, %r{^.+delete.?}, %r{^.+/destroy.?}], 
#                  :ignore_forms => [])
#     end
#   
#   end

# = SpiderTester
# 
# SpiderTester is an automated integration-testing script that iterates over every page in your application.
# It performs a few valuable tasks for you:
# 
# * parses the html of every page, so if you have invalid html or xml, you will be warned.
# * finds every link to within your site and follows it, whether static or dynamic.
# * finds every Ajax.Updater link and follows it.
# * finds every form and tries to submit it, filling in values where possible.
#   
# This is helpful in determining:
# 
# * missing static pages (.html)
# * poor code coverage - forgot to test a file?  Don't wait for a user to find it.
# * simple fuzzing of form values.
# * automated testing of form paths.  Often we have forms which point to incorrect
#   locations, and up until now this has been impossible to test in an automated fashion
#   or without being strongly coupled to your code.
# 

  # Begin spidering your application.
  # +body+:: the HTML request.body from a page in your app
  # +uri+::  the URL which generated the request.body. This is used in stack traces (followed link <...> from <uri>)
  # +options+:: A list of options for ignoring URLs, URL patterns, forms and form patterns
  #
  # The possible option are
  #         :ignore_urls : An array of URL strings and Regexp patterns that the spide should ignore
  #         :ignore_forms : An array of URL strings and Regexp patterns of form POST actions that the spider will ignore
  #         :verbose : Set this to true if you want extreme verbosity.
  #   
  # You can override certain instance methods if necessary:
  #    @links_to_visit : array containing SpiderIntegrator::Link.new( dest_url, source_url ) objects
  #   
  # You may find it useful to have two spider tests, one logged in and one logged out.
  def spider( body, uri, options )
    setup_spider(options)
    begin
      do_spider(body, uri)

    rescue Interrupt
      $stderr.puts "Caught CTRL-C"
    ensure
      finish
    end
  end
  
  @@last_perc = 0

  protected
  # You probably don't want to be calling these from within your test.

  def consume_page( html, url )
	  body = nil
    begin
      body = ActiveXML::Base.new html
    rescue
      puts "HARDCORE!! #{url}"
    end
    body.internal_data.traverse do |tag|
      next unless tag.element? 
      if tag.name == 'a'
        queue_link( tag, url ) unless tag['onclick']
      end
      if tag.name == 'link'
        queue_link( tag, url )
      end
    end
    @@last_perc.times { $stdout.write "\b" }
    $stdout.write "."
    perc = Integer(100 - @links_to_visit.size * 100 / (@links_to_visit.size + @visited_urls.size))
    $stdout.write "#{perc}%"
    if perc < 10
      @@last_perc = 1
    else
      @@last_perc = 2
    end
    @@last_perc += 1
  end
  
  def console(str)
    return unless @verbosity
    puts str
  end
  
  def setup_spider(options = {})
    options.reverse_merge!({ :ignore_urls => ['/logout'], :ignore_forms => ['/login'] })

    @ignore = {}
    @ignore[:urls] = Hash.new(false)
    @ignore[:url_patterns] = Hash.new(false)

    options[:ignore_urls].each do |option|
      @ignore[:url_patterns][option] = true if option.is_a? Regexp
      @ignore[:urls][option] = true if option.is_a? String
    end
    
    @verbosity = options[:verbose]
    
    console "Spidering will ignore the following URLs #{@ignore[:urls].keys.inspect}"
    console "Spidering will ignore the following URL patterns #{@ignore[:url_patterns].keys.inspect}"
    
    @links_to_visit ||= []
    @visited_urls = Hash.new(false)
    
    @visited_urls.merge! @ignore[:urls]
    
  end
  
  def spider_should_ignore_url?(uri)
     if @visited_urls[uri] then
       return true
     end
    
    @ignore[:url_patterns].keys.each do |pattern|
      if pattern.match(uri)
        console  "- #{uri} ( Ignored by pattern #{pattern.inspect})"
        @visited_urls[uri] = true
        return true 
      end
    end
    return false
  end
  
  # This is the actual worker method to grab the page.
  def do_spider( body, uri )

    @errors, @stacktraces = {}, {}
    @visited_urls[uri] = true
    consume_page( body, uri )
    until @links_to_visit.empty?
      next_link = @links_to_visit.shift
      next if spider_should_ignore_url?(next_link.uri)
      
      get next_link.uri
      if %w( 200 201 302 401 403 ).include?( @response.code )
        console "GET '#{next_link.uri}'"
      elsif @response.code == '404'
        #if next_link.uri =~ /\.(html|png|jpg|gif)$/ # static file, probably.
        if exists = File.exist?(File.expand_path("#{RAILS_ROOT}/public/#{next_link.uri}"))
          console "STATIC: #{next_link.uri}"
          case File.extname(next_link.uri)
          when /jpe?g|gif|psd|png|eps|pdf|css/
            console "Not parsing #{next_link.uri} because it looks like non-text" 
          when /html|te?xt|css|js/
            @response.body = File.open("#{RAILS_ROOT}/public/#{next_link.uri}").read
          else
            console "I don't know how to handle static file #{next_link.uri}. Send patches!"
          end
        else
          console  "? #{next_link.uri} ( 404 File not found from #{next_link.source} and File exist is #{exists})"          
          @errors[next_link.uri] = "File not found: #{next_link.uri} from #{next_link.source}"
        end
      else
        console  "! #{ next_link.uri } ( Received response code #{ @response.code }  - from #{ next_link.source } )"
        @errors[next_link.uri] = "Received response code #{ @response.code } for URI #{ next_link.uri } from #{ next_link.source }"
          
        @stacktraces[next_link.uri] = @response.body
      end
      @response.each { |chunk| consume_page( chunk, next_link.uri ) }
      @visited_urls[next_link.uri] = true
    end

  end
  
  # Finalize the test and display any errors.
  # Todo: make this look much better; and optionally save to a file instead of dumping to the page."
  def finish
    console  "\nFinished with #{@errors.size} error(s)."
    # todo: dump this in a file instead.
    err_dump = ""
    @errors.each do |url, error|
      err_dump << "\n#{'='*120}\n"
      err_dump << "ERROR:\t #{error}\n"
      err_dump << "URL  :\t #{url}\n"
      if @stacktraces[url] then
        err_dump << "STACK TRACE:\n"
        err_dump << @stacktraces[url]
      end
      err_dump << "\n#{'='*120}\n\n\n"
    end
    
    assert @errors.empty?, err_dump

    # reset our history. If you want to get access to some of these variables,
    # such as a trace of what you tested, don't clear them here!
    @visited_forms, @visited_urls, @links_to_visit, @forms_to_visit = nil
  end

  # Adds all <a href=..> links to the list of links to be spidered.
  # Adds all <link href=..> references to the list of pages to be spidered.
  # If it finds an Ajax.Updater url, it'll call that too.
  # Potentially there are other ajax links here to follow (TODO!)
  #
  # Will automatically ignore the following: 
  # * external links (starting with http://). This means, if you call foo_url in your app it will be ignored.
  # * mailto: links
  # * hex-encoded links (&#109;&#97;) generally encoded email addresses
  # * empty or purely anchor links (<a href="#foo"></a>)
  # * links where there is an ajax action, e.g. <a href="/foo/bar" onclick="new Ajax.Updater(...)">
  #   only the ajax action will be followed in that case.  This behavior probably should be changed
  #
  def queue_link( tag, source )
    onclick = tag['onclick']
    dest = (onclick =~ /^new Ajax.Updater\(['"].*?['"], ['"](.*?)['"]/i) ? $1 : tag['href']
    return if dest.nil?
    return if onclick =~ /confirm/
    dest.gsub!(/([?]\d+)$/, '') # fix asset caching
    unless dest =~ %r{^(http://|mailto:|#|&#)} 
      dest = dest.split('#')[0] if dest.index("#") # don't want page anchors
      return if dest.empty?
      return if spider_should_ignore_url?( dest )
      @links_to_visit << SpiderIntegrator::Link.new( dest, source ) # could be empty, make sure there's no empty links queueing
    end
  end

  SpiderIntegrator::Link = Struct.new( :uri, :source )
end 

require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class SpiderTest < ActionController::IntegrationTest

  include SpiderIntegrator

  @@errorurls = []

  def test_1spider
     get("/")
     setup_spider(:ignore_urls => [%r{irc:.*}, %r{bugzilla.novell.com}, '/user/logout'], :verbose => false )
     do_spider(@response.body, '')
     @@errorurls = @errors.keys
     assert_equal Hash.new, @errors
     logout
  end

  def test_2respider
     login_tom
     
     unless @@errorurls.empty?
       get @@errorurls[0]
       assert_response :success
     end
     logout
  end
end
