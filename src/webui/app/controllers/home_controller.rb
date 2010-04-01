class HomeController < ApplicationController

  before_filter :require_user

  def index
  end

  def list_requests
    @iprojects = @user.involved_projects.each.map {|x| x.name}.sort

    unless @iprojects.empty?
      predicate = @iprojects.map {|item| "action/target/@project='#{item}'"}.join(" or ")
      predicate2 = @iprojects.map {|item| "submit/target/@project='#{item}'"}.join(" or ") # old, to be removed later
      predicate = "state/@name='new' and (#{predicate} or #{predicate2})"
      collection = Collection.find_cached :what => :request, :predicate => predicate, :expires_in => 5.minutes
      myrequests = Hash.new
      collection.each do |req| myrequests[Integer(req.method_missing(:id))] = req end
      collection = Collection.find_cached :what => :request, :predicate => "state/@name='new' and state/@who='#{session[:login]}'", :expires_in => 5.minutes
      collection.each do |req| myrequests[Integer(req.method_missing(:id))] = req end
      @requests = Array.new
      keys = myrequests.keys().sort {|x,y| y <=> x}
      keys.each {|id| @requests << myrequests[id] }
    end
  end

  private

  def require_user
    unless session[:login]
      @error_message = "There must be a user logged in to show the homepage"
      render :template => 'error'
    end

    unless check_user
      unless check_user
        raise "There is no user #{session[:login]} known in the system." unless @user
      end
    end
  end
