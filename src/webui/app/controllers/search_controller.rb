class SearchController < ApplicationController

  before_filter :set_attribute_list

  def index
    @search_what = %w{package project}
  end

  def search
    redirect_to :action => "index" and return unless params[:search_text]

    @search_text = params[:search_text]
    if @search_text.starts_with?("obs://")
      # The user entered an OBS-specific RPM disturl, redirect to package source files with respective revision
      disturl_project, _, disturl_pkgrev = @search_text.split('/')[3..5]
      disturl_rev, disturl_package = disturl_pkgrev.split('-', 2)
      redirect_to :controller => 'package', :action => 'files', :project => disturl_project, :package => disturl_package, :rev => disturl_rev and return
    end

    @search_text = @search_text.gsub("'", "").gsub("[", "").gsub("]", "")
    @attribute = params[:attribute]
    if (!@search_text or @search_text.length < 2) && @attribute.blank?
      flash[:error] = "Search String must contain at least 2 characters OR you search for an attribute."
      redirect_to :action => 'index' and return
    end

    @search_what = %w{package project}
    if params[:advanced]
      @search_what = []
      @search_what << 'package' if params[:package]
      @search_what << 'project' if params[:project]
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

        unless @attribute.blank?
          if predicate.empty?
            predicate = "contains(attribute/@name,'#{@attribute}')"
          else
            predicate << " and contains(attribute/@name,'#{@attribute}')"
          end
        end

        if predicate.empty?
          flash[:error] = "You need to search for name, title, description or attributes."
          redirect_to :action => 'index' and return
        end
      else
        predicate = "contains(@name,'#{@search_text}')"
      end

      collection = find_cached(Collection, :what => s_what, :predicate => predicate, :expires_in => 5.minutes)

      # collect all results and give them some weight
      collection.send("each_#{s_what}") do |data|
        s = @search_text
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
        quoted_s = Regexp.quote(s)
        # weight the name
        if    (match = data.name.to_s.scan(/\b#{quoted_s}\b/i)) != []
          weight += match.length * weight_for[:name_full_match]
          log_weight(log_prefix, 'name_full_match', weight)
        elsif (match = data.name.to_s.scan(/\b#{quoted_s}/i)) != []
          weight += match.length * weight_for[:name_start_match]
          log_weight(log_prefix, 'name_start_match', weight)
        elsif (match = data.name.to_s.scan(/#{quoted_s}/i)) != []
          weight += match.length * weight_for[:name_contained]
          log_weight(log_prefix, 'name_contained', weight)
        end

        # weight the title
        if    (match = data.title.to_s.scan(/\b#{quoted_s}\b/i)) != []
          weight += match.length * weight_for[:title_full_match]
          log_weight(log_prefix, 'title_full_match', weight)
        elsif (match = data.title.to_s.scan(/\b#{quoted_s}/i)) != []
          weight += match.length * weight_for[:title_start_match]
          log_weight(log_prefix, 'title_start_match', weight)
        elsif (match = data.title.to_s.scan(/#{quoted_s}/i)) != []
          weight += match.length * weight_for[:title_contained]
          log_weight(log_prefix, 'title_contained', weight)
        end

        # weight the description
        if    (match = data.description.to_s.scan(/\b#{quoted_s}\b/i)) != []
          weight += match.length * weight_for[:description_full_match]
          log_weight(log_prefix, 'description_full_match', weight)
        elsif (match = data.description.to_s.scan(/\b#{quoted_s}/i)) != []
          weight += match.length * weight_for[:description_start_match]
          log_weight(log_prefix, 'description_start_match', weight)
        elsif (match = data.description.to_s.scan(/#{quoted_s}/i)) != []
          weight += match.length * weight_for[:description_contained]
          log_weight(log_prefix, 'description_contained', weight)
        end

        @results << {:type => s_what, :data => data, :weight => weight}
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
    attributes << find_cached(Attribute, :attributes, :namespace => d.data[:name].to_s)
  end
  attributes.each do |d|
    if d.has_element? :entry
      d.each {|f| @attribute_list << "#{d.init_options[:namespace]}:#{f.data[:name]}"}
    end
  end
end
