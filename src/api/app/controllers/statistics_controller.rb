
require 'rexml/document'
require "rexml/streamlistener"

class StatisticsController < ApplicationController

  validate_action :redirect_stats => {:method => :get, :response => :redirect_stats}

  before_filter :get_limit, :only => [
    :highest_rated, :most_active_packages, :most_active_projects, :latest_added, :latest_updated,
    :latest_built, :download_counter
  ]

  def index
    text =  "This is the statistics controller.<br />"
    text += "See the api documentation for details."
    render :text => text
  end


  def highest_rated
    # set automatic action_cache expiry time limit
    # response.time_to_live = 10.minutes

    ratings = Rating.select('db_object_id, db_object_type, count(score) as count,' +
        'sum(score)/count(score) as score_calculated').group('db_object_id, db_object_type').order('score_calculated DESC').all
    ratings = ratings.delete_if { |r| r.count.to_i < min_votes_for_rating }
    if @limit
      @ratings = ratings[0..@limit-1]
    else
      @ratings = ratings
    end
  end

  def rating
    @project = params[:project]
    @package = params[:package]

    object = Project.get_by_name(@project)
    object = DbPackage.get_by_project_and_name(@project, @package, use_source: false, follow_project_links: false) if @package

    if request.get?

      @rating = object.rating( @http_user.id )
      return

    elsif request.put?

      # try to get previous rating of this user for this object
      previous_rating = Rating.where('object_type=? AND object_id=? AND user_id=?', object.class.name, object.id, @http_user.id).first
      data = ActiveXML::Base.new( request.raw_post )
      if previous_rating
        # update previous rating
        previous_rating.score = data.to_s.to_i
        previous_rating.save
      else
        # create new rating entry
        begin
          rating = Rating.new
          rating.score = data.to_s.to_i
          rating.object_type = object.class.name
          rating.object_id = object.id
          rating.user_id = @http_user.id
          rating.save
        rescue
          render_error :status => 400, :errorcode => "error setting rating",
            :message => "rating not saved"
          return
        end
      end
      render_ok
      return
    end

    render_error :status => 400, :errorcode => "invalid_method",
      :message => "only GET or PUT method allowed for this action"
  end


  def download_counter
    # FIXME: download stats are currently not supported and needs a re-implementation

    render_error :status => 400, :errorcode => "not_supported", :message => "download stats need a re-implementation"
  end


  def newest_stats
    render_error :status => 400, :errorcode => "not_supported", :message => "download stats need a re-implementation"
  end
 

  def most_active_projects
    # get all packages including activity values
    @packages = DbPackage.select("db_packages.*, ( #{DbPackage.activity_algorithm} ) AS act_tmp," + 'IF( @activity<0, 0, @activity ) AS activity_value').
	    limit(@limit).order('activity_value DESC').all
    # count packages per project and sum up activity values
    projects = {}
    @packages.each do |package|
      pro = package.project.name
      projects[pro] ||= { :count => 0, :sum => 0 }
      projects[pro][:count] += 1
      projects[pro][:sum] += package.activity_value.to_f
    end

    # calculate average activity of packages per project
    projects.each_key do |pro|
      projects[pro][:activity] = projects[pro][:sum] / projects[pro][:count]
    end
    # sort by activity
    @projects = projects.sort do |a,b|
      b[1][:activity] <=> a[1][:activity]
    end

    return @projects
  end

  def most_active_packages
    # get all packages including activity values
    @packages = DbPackage.select("db_packages.*, ( #{DbPackage.activity_algorithm} ) AS act_tmp," + 'IF( @activity<0, 0, @activity ) AS activity_value').
      limit(@limit).order('activity_value DESC').all
    return @packages
  end


  def activity
    @project = Project.get_by_name(params[:project])
    @package = DbPackage.get_by_project_and_name(params[:project], params[:package], use_source: false, follow_project_links: false) if params[:package]
  end


  def latest_added

    packages = DbPackage.limit(@limit).order('created_at DESC, name').all
    projects = Project.limit(@limit).order('created_at DESC, name').all

    list = projects 
    list.concat packages
    list.sort! { |a,b| b.created_at <=> a.created_at }


    if @limit
      @list = list[0..@limit-1]
    else
      @list = list
    end
  end


  def added_timestamp

    @project = Project.get_by_name(params[:project])
    @package = DbPackage.get_by_project_and_name(params[:project], params[:package], use_source: false, follow_project_links: true)

    # is it used at all ?
  end


  def latest_updated
    @limit = 10 unless @limit
    # first we catch a list visible to anyone
    # not just needs this to be fast, it also needs to catch errors in case projects or packages
    # disappear after the cache hit. So we do not spend too much logic in access flags, but check
    # the cached values afterwards if they are valid and accessible
    packages = DbPackage.select("id,updated_at").order("updated_at DESC").limit(@limit*2).all
    projects = Project.select("id,updated_at").order("updated_at DESC").limit(@limit*2).all

    list = projects
    list.concat packages
    ret = Array.new
    list.sort { |a,b| b.updated_at <=> a.updated_at }.each do |item|
      if item.instance_of? DbPackage
        ret << [:package, item.id]
      else
        ret << [:project, item.id]
      end
    end
    list = ret

    @list = Array.new
    list.each do |type, id|
      if type == :project
        item = Project.find(id)
        next unless Project.check_access?(item)
      else
        item = DbPackage.find(id)
        next unless item
        next unless DbPackage.check_access?(item)
      end
      @list << item
      break if @list.size == @limit
    end
  end


  def updated_timestamp

    @project = Project.get_by_name(params[:project])
    @package = DbPackage.get_by_project_and_name(params[:project], params[:package], use_source: false, follow_project_links: true)

  end


  def global_counters

    @users = User.count
    @repos = Repository.count
    @projects = Project.count
    @packages = DbPackage.count
  end


  def latest_built
    # set automatic action_cache expiry time limit
    #    response.time_to_live = 10.minutes

    # TODO: implement or decide to abolish this functionality
  end


  def get_limit
    return @limit = nil if not params[:limit].nil? and params[:limit].to_i == 0
    @limit = 10 if (@limit = params[:limit].to_i) == 0
  end

end
