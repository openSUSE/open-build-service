class SearchController < ApplicationController

  before_filter :set_attribute_list
  before_filter :set_tracker_list
  before_filter :set_parameters
  
  def index
    search
  end
  
  def owner
    search
  end
  # The search method does the search and renders the results
  # if there is something to search for. If not then it just
  # renders a search bar.
  #
  #  * *Args* :
  #   - @search_text -> The search string we search for
  #   - @search_what -> Array of result limits
  #   - @search_where -> Array of where we search
  #   - @search_attribute -> Limit results to this attribute string
  #   - @search_issue -> Limit results to packages with this issue in the changelog
  #   - @owner_limit -> Limit the amount of owners
  #   - @owner_devel -> Follow devel links for owner search
  # * *Returns* :
  #   - +@results+ -> An array of results
  def search
    # If there is nothing to search for, just return
    return unless params[:search_text]
    # If the search is too short, return too
    if (!@search_text or @search_text.length < 2) && !@search_attribute && !@search_issue
      flash[:error] = "Search string must contain at least two characters."
      return
    end
    
    if @search_text.starts_with?("obs://")
    # The user entered an OBS-specific RPM disturl, redirect to package source files with respective revision
      unless handle_disturl(@search_text)
        flash[:error] = "This disturl does not compute!"
        return
      end
    end

    logger.debug "Searching for the string #{@search_text} in the #{@search_where}'s of #{@search_what}'s"
    if @search_where.length < 1 and !@search_attribute and !@search_issue
      flash[:error] = "You have to search for #{@search_text} in something. Click the advanced button..."
      return
    end

    @search_what.each do |what|
      pand = []

      if what == 'owner'
        collection = find_cached(Owner, :binary => "#{@search_text}", :limit => "#{@owner_limit}", :devel => "#{@owner_devel}", :expires_in => 5.minutes)
        reweigh(collection, what)
      end
      if what == 'package' or what == 'project'
        p = []
        p << "contains(@name,'#{@search_text}')" if @search_where.include?('name')
        p << "contains(title,'#{@search_text}')" if @search_where.include?('title')
        p << "contains(description,'#{@search_text}')" if @search_where.include?('description')
        pand << p.join(' or ')
        if @search_attribute
          pand << "contains(attribute/@name,'#{@search_attribute}')"
        end
        if @search_issue
          tracker_name = params[:issue_tracker].gsub(/ .*/,'')
          # could become configurable in webui, further options would be "changed" or "deleted".
          # best would be to prefer links with "added" on top of results
          pand << "issue/[@name=\"#{@search_issue}\" and @tracker=\"#{tracker_name}\" and (@change='added' or @change='kept')]"
        end
        predicate = pand.join(' and ')
        if predicate.empty?
          flash[:error] = "You need to search for name, title, description or attributes."
          return
        else
          collection = find_cached(Collection, :what => what, :predicate => "[#{predicate}]", :expires_in => 5.minutes)
          reweigh(collection, what)
        end
      end

      if @results.length < 1
        flash[:note] = "Your search did not return any results."
      end
      if @results.length > 200
        @results = @results[0..199]
        flash[:note] = "Your search returned more than 200 results. Please be more precise."
      end
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
      logger.debug "Computing disturl #{disturl} failed"
      return false
  end

  # This method collects all results and gives them some weight
  #
  # * *Args* :
  #   - +collection+ -> A collection
  #   - +what+ ->  String of the type of search. Like package, project, owner...
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

  # This sets the needed defaults and input we've got for instance variables
  #
  # * *Returns* :
  #   - @search_text -> The search string we search for
  #   - @search_what -> Array of result limits
  #   - @search_where -> Array of where we search
  #   - @search_attribute -> Limit results to this attribute string
  #   - @search_issue -> Limit results to packages with this issue in the changelog
  #   - @owner_limit -> Limit the amount of owners
  #   - @owner_devel -> Follow devel links for owner search
  #   - @results -> An empty array for the results
  #
  def set_parameters
    @results = []

    @search_attribute = nil
    @search_attribute = params[:attribute].strip unless params[:attribute].blank?

    @search_issue = nil
    @search_issue = params[:issue].strip unless params[:issue].blank?

    @search_text = ""
    @search_text = params[:search_text].strip unless params[:search_text].blank?
    @search_text = @search_text.gsub("'", "").gsub("[", "").gsub("]", "").gsub("\n", "")
   
    @search_what = []
    @search_what << 'package' if params[:package] == "1" or params[:package].nil?
    @search_what << 'project' if params[:project] == "1" or params[:project].nil? and !@search_issue
    @search_what << 'owner' if params[:owner] == "1" and !@search_issue
    
    @search_where = []
    @search_where << 'name' if params[:name] == "1" or params[:name].nil?
    @search_where << 'title' if params[:title] == "1"
    @search_where << 'description' if params[:description] == "1"
    
    @owner_limit = nil
    @owner_limit = "1" if params[:limit].nil?
    @owner_limit = params[:limit] if !params[:limit].nil?
    
    @owner_devel = nil
    @owner_devel = "0" if params[:devel].nil?
    @owner_devel = params[:devel] if !params[:devel].nil?
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
