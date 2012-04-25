ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

require 'webrat'

Webrat.configure do |config|
   config.mode = :rails
end

# Webrat Rails-3 compatibilty hack to be used instead of 'https://github.com/kalv/webrat.
# See http://groups.google.com/group/webrat/browse_thread/thread/fb5ff3fccd97f3df
# Webrat.configure do |config|
#    config.mode = :rack
# end
# module Webrat
#   class Session
#     def current_host
#       URI.parse(current_url).host || @custom_headers['Host'] || default_current_host
#     end
#     def default_current_host
#       adapter.class==Webrat::RackAdapter ? 'example.org' : 'www.example.com'
#     end 
#   end
#   class Link
#     def click_post(options = {})
#       method = options[:method] || http_method
#       return if href =~ /^#/ && method == :get
#       @session.request_page(absolute_href, method, data)
#     end
#   end
# end

module ActionController
  class IntegrationTest
    # will provide a user without special permissions
    def login_tom
      post '/user/do_login', :username => 'tom', :password => 'thunder', :return_to_path => '/'
      assert_redirected_to '/'
      assert_equal "You are logged in now", @request.flash[:success]
    end

    def login_Iggy
      post '/user/do_login', :username => 'Iggy', :password => 'asdfasdf', :return_to_path => '/'
      assert_redirected_to '/'
      assert_equal "You are logged in now", @request.flash[:success]
    end

    def login_adrian
      post '/user/do_login', :username => 'adrian', :password => 'so_alone', :return_to_path => '/'
      assert_redirected_to '/'
      assert_equal "You are logged in now", @request.flash[:success]
    end

    def logout
      post '/user/logout'
    end
  end
end
