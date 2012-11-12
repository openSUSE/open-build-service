class AdminController < ApplicationController
  skip_before_filter :extract_user

  @@started = false

  # we need a way so the API sings killing me softly
  # of course we don't want to have this action visible 
  hide_action :killme unless Rails.env.test?
  def killme
    Process.kill('INT', Process.pid)
    @@started = false
    render_ok
  end
  
  # we need a way so the API uprises fully
  # of course we don't want to have this action visible 
  hide_action :startme unless Rails.env.test?
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
  
end
