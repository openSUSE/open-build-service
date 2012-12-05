class SearchController < ApplicationController

  before_filter :set_attribute_list
  before_filter :set_tracker_list
  before_filter :set_parameters
  # The index method does the search and renders the results if there is something to search for.
  # If not then it just renders a search bar.
  #
  #  * *Args* :
  #   - +@search_text+ -> The string to search for
  #   - +@search_issue+ -> The issue number to search for
  #   - +@attribute+ -> The attribute to search for
  #   - +:package+ -> Search for packages (default)
  #   - +:project+ -> Search for projects (default)
  #   - +:owner+ -> Search for owners
  # * *Returns* :
  #   - +@results+ -> An array of results
  def index
    # If there is nothing to search for, just return
    return unless params[:search_text]
    # Set the needed instance variables from the paraemters

    # If the search is too short, return too
    if (!@search_text or @search_text.length < 2) && !@attribute && !@search_issue
      flash[:error] = "Search string must contain at least two characters"
      return
    end
    
    if @search_text.starts_with?("obs://")
    # The user entered an OBS-specific RPM disturl, redirect to package source files with respective revision
      handle_disturl(@search_text)
    end

    if params[:advanced]
      @search_what = []
      @search_what << 'package' if params[:package]
      @search_what << 'project' if params[:project] and !@search_issue
      @search_what << 'project' if params[:owner] and !@search_issue    
    end

    @search_what.each do |s_what|
    # build xpath predicate
      if params[:advanced]
        pand = []
        if @search_text
          p = []
          p << "contains(@name,'#{@search_text}')" if params[:name]
          p << "contains(title,'#{@search_text}')" if params[:title]
          p << "contains(description,'#{@search_text}')" if params[:description]
          pand << p.join(' or ')
        end
        if @search_issue
          tracker_name = params[:issue_tracker].gsub(/ .*/,'')
          # could become configurable in webui, further options would be "changed" or "deleted".
          # best would be to prefer links with "added" on top of results
          changes="@change='added' or @change='kept'" 
          pand << "issue/[@name=\"#{@search_issue}\" and @tracker=\"#{tracker_name}\" and (#{changes})]"
        end
        if @attribute
          pand << "contains(attribute/@name,'#{@attribute}')"
        end
        predicate = pand.join(' and ')
        if predicate.empty?
          flash[:error] = "You need to search for name, title, description or attributes."
          return
        end
      else
        predicate = "contains(@name,'#{@search_text}')"
      end
      collection = find_cached(Collection, :what => s_what, :predicate => "[#{predicate}]", :expires_in => 5.minutes)
      reweigh(collection, s_what)
      logger.debug "@results in index: #{@results.length}"
    end
  end

  # This method handles obs:// disturls
  #
  # * *Args* :
  #   - +disturl+ -> A dist url string like obs://INSTANCE/PROJECT/REPO/REVISION-PACKAGE
  #   obs://build.opensuse.org/openSUSE:Maintenance:1055/openSUSE_12.2_Update/255b363336b47a513d4df73a92bc2acc-aaa_base.openSUSE_12.2_Update
  # * *Returns* :
  #   - 
  # * *Redirects* :
  #   - +package/show+ -> if the disturl is computeable
  #   - +search/index+ -> if the disturl isn't computeable
  # * *Raises* :
  #   - 
  #
  def handle_disturl(disturl)
    disturl_project, _, disturl_pkgrev = disturl.split('/')[3..5]
      unless disturl_pkgrev.nil? 
        disturl_rev, disturl_package = disturl_pkgrev.split('-', 2)
      end
      unless disturl_package.nil? || disturl_rev.nil?
        redirect_to :controller => 'package', :action => 'show', :project => disturl_project, :package => disturl_package, :rev => disturl_rev and return
      end
      flash[:error] = "This obs:// disturl doesn't compute!"
      return
  end

  # This method collects all results and gives them some weight
  #
  # * *Args* :
  #   - +collection+ -> A collection
  #   - +what+ ->  String og the type of search. Like package, project, owner...
  # * *Returns* :
  #   - +@results+ -> A collection ordered by weight
  # * *Raises* :
  #   
  #
  def reweigh(collection, what)
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

    r = []

    collection.send("each_#{what}") do |result|
      weight = 0
      log_prefix = "weighting search result #{what} \"#{result.name}\" by"
      # weight if result is a project
      if what == 'project'
        weight += weight_for[:is_a_project]
        log_weight(log_prefix, 'is_a_project', weight)
      end
      # TODO: prefer links with added issues on issue search
      if @search_text
        # weight if name matches exact
        if result.name.to_s.downcase == @search_text.downcase
          weight += weight_for[:name_exact_match]
          log_weight(log_prefix, 'name_exact_match', weight)
        end
        quoted_search_text = Regexp.quote(@search_text)
        # weight the name
        if (match = result.name.to_s.scan(/\b#{quoted_search_text}\b/i)) != []
          weight += match.length * weight_for[:name_full_match]
          log_weight(log_prefix, 'name_full_match', weight)
        elsif (match = result.name.to_s.scan(/\b#{quoted_search_text}/i)) != []
          weight += match.length * weight_for[:name_start_match]
          log_weight(log_prefix, 'name_start_match', weight)
        elsif (match = result.name.to_s.scan(/#{quoted_search_text}/i)) != []
          weight += match.length * weight_for[:name_contained]
          log_weight(log_prefix, 'name_contained', weight)
        end
        # weight the title
        if (match = result.title.to_s.scan(/\b#{quoted_search_text}\b/i)) != []
          weight += match.length * weight_for[:title_full_match]
          log_weight(log_prefix, 'title_full_match', weight)
        elsif (match = result.title.to_s.scan(/\b#{quoted_search_text}/i)) != []
          weight += match.length * weight_for[:title_start_match]
          log_weight(log_prefix, 'title_start_match', weight)
        elsif (match = result.title.to_s.scan(/#{quoted_search_text}/i)) != []
          weight += match.length * weight_for[:title_contained]
          log_weight(log_prefix, 'title_contained', weight)
        end
        # weight the description
        if (match = result.description.to_s.scan(/\b#{quoted_search_text}\b/i)) != []
          weight += match.length * weight_for[:description_full_match]
          log_weight(log_prefix, 'description_full_match', weight)
        elsif (match = result.description.to_s.scan(/\b#{quoted_search_text}/i)) != []
          weight += match.length * weight_for[:description_start_match]
          log_weight(log_prefix, 'description_start_match', weight)
        elsif (match = result.description.to_s.scan(/#{quoted_search_text}/i)) != []
           weight += match.length * weight_for[:description_contained]
          log_weight(log_prefix, 'description_contained', weight)
        end
      end
      r << {:type => what, :data => result, :weight => weight}
    end
    # return results reordered by weight
    r.sort! {|a,b| b[:weight] <=> a[:weight]}    
    @results.concat(r)
    if @results.length < 1
      flash.now[:error] = "Your search didn't return any results"
    end
    if @results.length > 200
      @results = @results[0..199]
      flash.now[:note] = "Your search returned more than 200 results. Please be more precise."
    end
  end

  # This method logs the weight something is given to
  #
  # * *Args* :
  #   - +log_prefix+ -> A prefix string for the log message
  #   - +reason+ -> A string of the reason for the weight
  #   - +new_weight+ -> A fixnum of the weight given
  #
  def log_weight(log_prefix, reason, new_weight)
    logger.debug "#{log_prefix} #{reason}, new weight=#{new_weight}"
  end

private

  # This sets the needed instance variables from the parameters
  # we've got from the user input.
  #
  # * *Returns* :
  #   - @search_text -> The search string we search for
  #   - @search_issue -> The issue number we search for
  #   - @attribute -> The attribute we search for
  #
  def set_parameters
    # default: searching for package and project
    @search_what = %w{package project}
    @results = []
    @search_text = ""
    @search_text = params[:search_text].strip unless params[:search_text].blank?
    @search_text = @search_text.gsub("'", "").gsub("[", "").gsub("]", "").gsub("\n", "")
    @search_issue = nil
    @search_issue = params[:issue_name].strip unless params[:issue_name].blank?
    @attribute = nil
    @attribute = params[:attribute].strip unless params[:attribute].blank?
  end

  def set_attribute_list
    namespaces = find_cached(Attribute, :namespaces)
    attributes = []
    @attribute_list = ['']
    namespaces.each do |d|
      attributes << find_cached(Attribute, :attributes, :namespace => d.value(:name))
    end
    attributes.each do |d|
      if d.has_element? :entry
        d.each {|f| @attribute_list << "#{d.init_options[:namespace]}:#{f.value(:name)}"}
      end
    end
  end

  def set_tracker_list
    trackers = find_cached(IssueTracker, :all)
    @issue_tracker_list = []
    trackers.each("/issue-trackers/issue-tracker") do |t|
      @issue_tracker_list << "#{t.name.text} (#{t.description.text})"
    end
    @issue_tracker_list.sort!
  end
  
end
