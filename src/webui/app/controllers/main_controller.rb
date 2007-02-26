class MainController < ApplicationController

  skip_before_filter :authorize, :only => [
    :index, :latest_added, :latest_updated, :most_downloaded, :highest_rated
  ]


  def index
    #
  end

  def index2
    redirect_to "/"
  end

  def statistics
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
    render :partial => 'download_details', :layout => true
  end


  def search
    ### search form
  end


  def search_advanced
    ### advanced search form
  end


  ### generate search results
  def search_result
    @search_text = params[:search_text]

    if !@search_text or @search_text.length < 2
      flash[:error] = "Search String must contain at least 2 Characters."
      redirect_to :controller => 'main', :action => 'search'
      return
    end

    logger.debug "performing search: search_text='#{@search_text}'"

    if params[:advanced]
      @search_what = []
      @search_what << 'package' if params[:package]
      @search_what << 'project' if params[:project]
    else
      @search_what = %w{ package project }
    end

    weight_for = {
      :is_a_project      => 10,
      :name_exact_match  => 20,
      :name_full_match   => 16,
      :name_start_match  => 8,
      :name_contained    => 4,
      :title_full_match  => 8,
      :title_start_match => 4,
      :title_contained   => 2,
      :description_full_match  => 4,
      :description_start_match => 2,
      :description_contained   => 1
    }

    @results = []
    @search_what.each do |s_what|

      # build xpath predicate
      if params[:advanced]
        p = []
        p << "contains(@name,'#{@search_text}')" if params[:name]
        p << "contains(title,'#{@search_text}')" if params[:title]
        p << "contains(description,'#{@search_text}')" if params[:description]
        predicate = p.join(' or ')
        if predicate.empty?
          flash[:error] = "You need to choose name, title or description."
          return
        end
      else
        predicate = "contains(@name,'#{@search_text}') or contains(title,'#{@search_text}') or contains(description,'#{@search_text}')"
      end

      collection = Collection.find( :what => s_what, :predicate => predicate )

      # collect all results and give them some weight
      collection.send("each_#{s_what}") do |data|

        s = @search_text
        count = 0
        weight = 0

        log_prefix = "weighting search result #{s_what} \"#{data.name}\" by"

        # weight if result is a project
        if s_what == 'project'
          weight += weight_for[:is_a_project]
          log_weight(log_prefix, 'is_a_project', weight)
        end

        # weight if name matches exact
        if data.name.to_s.downcase == @search_text.downcase
          weight += weight_for[:name_exact_match]
          log_weight(log_prefix, 'name_exact_match', weight)
        end

        # weight the name
        if    (match = data.name.to_s.scan(/\b#{s}\b/i)) != []
          weight += match.length * weight_for[:name_full_match]
          log_weight(log_prefix, 'name_full_match', weight)
        elsif (match = data.name.to_s.scan(/\b#{s}/i)) != []
          weight += match.length * weight_for[:name_start_match]
          log_weight(log_prefix, 'name_start_match', weight)
        elsif (match = data.name.to_s.scan(/#{s}/i)) != []
          weight += match.length * weight_for[:name_contained]
          log_weight(log_prefix, 'name_contained', weight)
        end

        # weight the title
        if    (match = data.title.to_s.scan(/\b#{s}\b/i)) != []
          weight += match.length * weight_for[:title_full_match]
          log_weight(log_prefix, 'title_full_match', weight)
        elsif (match = data.title.to_s.scan(/\b#{s}/i)) != []
          weight += match.length * weight_for[:title_start_match]
          log_weight(log_prefix, 'title_start_match', weight)
        elsif (match = data.title.to_s.scan(/#{s}/i)) != []
          weight += match.length * weight_for[:title_contained]
          log_weight(log_prefix, 'title_contained', weight)
        end

        # weight the description
        if    (match = data.description.to_s.scan(/\b#{s}\b/i)) != []
          weight += match.length * weight_for[:description_full_match]
          log_weight(log_prefix, 'description_full_match', weight)
        elsif (match = data.description.to_s.scan(/\b#{s}/i)) != []
          weight += match.length * weight_for[:description_start_match]
          log_weight(log_prefix, 'description_start_match', weight)
        elsif (match = data.description.to_s.scan(/#{s}/i)) != []
          weight += match.length * weight_for[:description_contained]
          log_weight(log_prefix, 'description_contained', weight)
        end

        @results << { :type => s_what, :data => data, :weight => weight }
      end
    end

    # reorder results by weight
    @results.sort! { |a,b| b[:weight] <=> a[:weight] }
  end


  def log_weight(log_prefix, reason, new_weight)
    logger.debug "#{log_prefix} #{reason}, new weight=#{new_weight}"
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
