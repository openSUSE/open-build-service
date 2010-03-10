class AdminController < ApplicationController

  skip_before_filter :require_login, :only => [:login, :do_login]

  def connect_instance
    # nothing to do yet, we show all existing and possible remote
    # instances here later
  end


  def save
   redirect_to :controller => "project", :action => :save_new, 
               :name => params[:project], :remoteurl => params[:remoteurl],
               :title => "Remote OBS instance for " + params[:project], 
               :description => "This project is representing a remote build service instance."
  end


end
