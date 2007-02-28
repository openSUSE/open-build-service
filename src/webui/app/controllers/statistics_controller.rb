class StatisticsController < ApplicationController


  skip_before_filter :authorize, :only => [
    :index, :latest_added, :latest_updated, :most_downloaded, :highest_rated
  ]


  def index
    @latest_added    = LatestAdded.find( :limit => 10 )
    @latest_updated  = LatestUpdated.find( :limit => 10 )
    @highest_rated   = Rating.find( :all, :limit => 10 )
    @limit = 3
    @most_downloaded = get_download_stats
  end


  def latest_added
    limit = params[:limit]
    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    @latest_added = LatestAdded.find( :limit => limit )
    render :partial => 'latest_added', :layout => layout, :more => true
  end


  def latest_updated
    limit = params[:limit]
    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    @latest_updated = LatestUpdated.find( :limit => limit )
    render :partial => 'latest_updated', :layout => layout, :more => true
  end


  def most_downloaded
    @limit = params[:limit]
    @most_downloaded = get_download_stats
    render :partial => 'most_downloaded', :layout => true, :more => true
  end


  def highest_rated
    limit = params[:limit]
    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    @highest_rated = Rating.find( :all, :limit => limit )
    render :partial => 'highest_rated', :layout => layout, :more => true
  end


  def download_details
    limit = params[:limit]
    project = params[:project]
    package = params[:package]
    repo = params[:repo]
    arch = params[:arch]

    if project and package
      @name = "#{package} (project #{project})"
      @title = 'Package'
      @downloads = Downloadcounter.find(
        :project => params[:project], :package => params[:package],
        :limit => limit
      )
    elsif project
      @name = project
      @title = 'Project'
      @downloads = Downloadcounter.find(
        :project => params[:project], :limit => limit
      )
    elsif arch
      @name = arch
      @title = 'Architecture'
      @downloads = Downloadcounter.find(
        :arch, :arch => params[:arch], :limit => limit
      )
    elsif repo
      @name = repo
      @title = 'Repository'
      @downloads = Downloadcounter.find(
        :repo, :repo => params[:repo], :limit => limit
      )
    else
      @name = 'all downloads'
      @title = ''
      @downloads = Downloadcounter.find( :all, :limit => limit )
    end
    # no layout, if this is an ajax-request
    request.get? ? layout=true : layout=false
    render :partial => 'download_details', :layout => layout
  end


  private


  def get_download_stats
    most_downloaded = {}
    most_downloaded[:projects] = Downloadcounter.find(
      :concat => 'project', :limit => @limit
    )
    most_downloaded[:packages] = Downloadcounter.find(
      :concat => 'package', :limit => @limit
    )
    most_downloaded[:repos] = Downloadcounter.find(
      :concat => 'repository', :limit => @limit
    )
    most_downloaded[:archs] = Downloadcounter.find(
      :concat => 'architecture', :limit => @limit
    )
    return most_downloaded
  end


end
