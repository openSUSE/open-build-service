if Rails.env.test? || Rails.env.development?
  require 'database_cleaner'
  DatabaseCleaner.strategy = :transaction
end

class TestController < ApplicationController
  skip_before_filter :extract_user
  before_filter do 
    return true if Rails.env.test? || Rails.env.development?
    render_error  message: "This is only accessible for testing environments", :status => 403
    return false
  end

  @@started = false

  # we need a way so the API sings killing me softly
  def killme
    Process.kill('INT', Process.pid)
    @@started = false
    render_ok
  end
  
  # we need a way so the API uprises fully
  def startme
     if @@started == true
       render_ok
       return
     end
     @@started = true
     system("cd #{Rails.root.to_s}; unset BUNDLE_GEMFILE; RAILS_ENV=test exec bundle exec rake db:fixtures:load")
     # for requests the ID is user visible, so reset it to get reproducible results
     max=BsRequest.maximum(:id)
     BsRequest.connection.execute("alter table bs_requests AUTO_INCREMENT = #{max+1}")
     backend.direct_http(URI("/"))
     render_ok
  end
  
  def test_start
    DatabaseCleaner.start
    render_ok
  end


  def test_end
    DatabaseCleaner.clean
    Rails.cache.clear
    render_ok
  end
end
