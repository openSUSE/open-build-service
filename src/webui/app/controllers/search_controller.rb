class SearchController < ApplicationController

  before_filter :set_attribute_list
  before_filter :set_tracker_list

  def index
    @search_what = %w{package project}
  end

  def search
    redirect_to :action => "index" and return unless params[:search_text]

    @search_text = nil
    unless params[:search_text].blank?
      @search_text = params[:search_text].strip
      if @search_text.starts_with?("obs://")
        # The user entered an OBS-specific RPM disturl, redirect to package source files with respective revision
        disturl_project, _, disturl_pkgrev = @search_text.split('/')[3..5]
	unless disturl_pkgrev.nil? 
          disturl_rev, disturl_package = disturl_pkgrev.split('-', 2)
	  unless disturl_package.nil? || disturl_rev.nil?
            redirect_to :controller => 'package', :action => 'files', :project => disturl_project, :package => disturl_package, :rev => disturl_rev 
	  end
	  return
	end
	# if we're here, we're screwed
	# TODO: document the purpose
	flash[:error] = "obs:// searches are not random"
	redirect_to :action => 'index' and return
      end
      @search_text = @search_text.gsub("'", "").gsub("[", "").gsub("]", "").gsub("\n", "")
    end

    @search_issue = nil
    @search_issue = params[:issue_name].strip unless params[:issue_name].blank?

    @attribute = nil
    @attribute = params[:attribute] unless params[:attribute].blank?

    if (!@search_text or @search_text.length < 2) && !@attribute && !@search_issue
      flash[:error] = "Search String must contain at least 2 characters OR you search for an attribute."
      redirect_to :action => 'index' and return
    end

    @search_what = %w{package project}
    if params[:advanced]
      @search_what = []
      @search_what << 'package' if params[:package]
      @search_what << 'project' if params[:project] and !@search_issue
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
          changes="@change='added' or @change='kept'" # could become configurable in webui, further options would be "changed" or "deleted".
                                                      # best would be to prefer links with "added" on top of results
          pand << "issue/[@name=\"#{@search_issue}\" and @tracker=\"#{tracker_name}\" and (#{changes})]"
        end
        if @attribute
          pand << "contains(attribute/@name,'#{@attribute}')"
        end

        predicate = pand.join(' and ')

        if predicate.empty?
          flash[:error] = "You need to search for name, title, description or attributes."
          redirect_to :action => 'index' and return
        end
      else
        predicate = "contains(@name,'#{@search_text}')"
      end
      collection = find_cached(Collection, :what => s_what, :predicate => "[#{predicate}]", :expires_in => 5.minutes)

      # collect all results and give them some weight
      collection.send("each_#{s_what}") do |result|

        weight = 0

        log_prefix = "weighting search result #{s_what} \"#{result.name}\" by"

        # weight if result is a project
        if s_what == 'project'
          weight += weight_for[:is_a_project]
          log_weight(log_prefix, 'is_a_project', weight)
        end

        # IMPLEMENT_ME: prefer links with added issues on issue search

        if @search_text
          s = @search_text

          # weight if name matches exact
          if result.name.to_s.downcase == s.downcase
            weight += weight_for[:name_exact_match]
            log_weight(log_prefix, 'name_exact_match', weight)
          end

          quoted_s = Regexp.quote(s)
          # weight the name
          if    (match = result.name.to_s.scan(/\b#{quoted_s}\b/i)) != []
            weight += match.length * weight_for[:name_full_match]
            log_weight(log_prefix, 'name_full_match', weight)
          elsif (match = result.name.to_s.scan(/\b#{quoted_s}/i)) != []
            weight += match.length * weight_for[:name_start_match]
            log_weight(log_prefix, 'name_start_match', weight)
          elsif (match = result.name.to_s.scan(/#{quoted_s}/i)) != []
            weight += match.length * weight_for[:name_contained]
            log_weight(log_prefix, 'name_contained', weight)
          end

          # weight the title
          if    (match = result.title.to_s.scan(/\b#{quoted_s}\b/i)) != []
            weight += match.length * weight_for[:title_full_match]
            log_weight(log_prefix, 'title_full_match', weight)
          elsif (match = result.title.to_s.scan(/\b#{quoted_s}/i)) != []
            weight += match.length * weight_for[:title_start_match]
            log_weight(log_prefix, 'title_start_match', weight)
          elsif (match = result.title.to_s.scan(/#{quoted_s}/i)) != []
            weight += match.length * weight_for[:title_contained]
            log_weight(log_prefix, 'title_contained', weight)
          end

          # weight the description
          if    (match = result.description.to_s.scan(/\b#{quoted_s}\b/i)) != []
            weight += match.length * weight_for[:description_full_match]
            log_weight(log_prefix, 'description_full_match', weight)
          elsif (match = result.description.to_s.scan(/\b#{quoted_s}/i)) != []
            weight += match.length * weight_for[:description_start_match]
            log_weight(log_prefix, 'description_start_match', weight)
          elsif (match = result.description.to_s.scan(/#{quoted_s}/i)) != []
            weight += match.length * weight_for[:description_contained]
            log_weight(log_prefix, 'description_contained', weight)
          end
        end

        @results << {:type => s_what, :data => result, :weight => weight}
      end
    end

    # reorder results by weight
    @results.sort! {|a,b| b[:weight] <=> a[:weight]}
  end

  def log_weight(log_prefix, reason, new_weight)
    logger.debug "#{log_prefix} #{reason}, new weight=#{new_weight}"
  end

end

private

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
