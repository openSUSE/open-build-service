class AdminController < ApplicationController
  skip_before_filter :extract_user, :only => [:killme, :startme]
  before_filter :require_admin, :except => [:killme, :startme]

  # we need a way so the API sings killing me softly
  # of course we don't want to have this action visible 
  hide_action :killme unless Rails.env.test?
  def killme
    if Rails.env.test?
      Process.kill('INT', Process.pid)
    end
    render :nothing => true and return
  end
  
  # we need a way so the API uprises fully
  # of course we don't want to have this action visible 
  hide_action :startme unless Rails.env.test?
  def startme
     if Rails.env.test?
       backend.direct_http(URI("/"))
     end
     render :nothing => true and return
  end
  
end
