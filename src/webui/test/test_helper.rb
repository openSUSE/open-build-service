ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'test/unit/assertions'

require 'webrat'

Webrat.configure do |config|
   config.mode = :rack
end

module ActionController
  class IntegrationTest
    # will provide a user without special permissions
    def login_tom
      post '/user/do_login', :username => 'tom', :password => 'thunder', :return_to_path => '/'
      follow_redirect!
      assert_contain("You are logged in now")
    end

    def login_Iggy
      post '/user/do_login', :username => 'Iggy', :password => 'asdfasdf', :return_to_path => '/'
      follow_redirect!
      assert_contain("You are logged in now")
    end

    def login_adrian
      post '/user/do_login', :username => 'adrian', :password => 'so_alone', :return_to_path => '/'
      follow_redirect!
      assert_contain("You are logged in now")
    end

    def logout
      post '/user/logout'
    end
  end
end
