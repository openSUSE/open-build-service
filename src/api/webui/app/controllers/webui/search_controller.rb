class Webui::SearchController < Webui::WebuiController

  before_filter :set_attribute_list
  before_filter :set_tracker_list
  before_filter :set_parameters
  
  def index
    search
  end
  
  def owner
    Suse::Backend.start_test_backend if Rails.env.test?

    # If the search is too short, return
    return if @search_text.blank?
    if @search_text and @search_text.length < 2
      flash[:error] = "Search string must contain at least two characters."
      return
    end

    @results = Owner.search({:limit => "#{@owner_limit}", :devel => "#{@owner_devel}"}, @search_text)
    flash[:notice] = 'Your search did not return any results.' if @results.count < 1
  end

  # The search method does the search and renders the results
  # if there is something to search for. If not then it just
  # renders a search bar.
  #
  #  * *Args* :
  #   - @search_text -> The search string we search for
  #   - @search_what -> Array of result limits
  #   - @search_where -> Array of where we search
  #   - @search_attrib_type_id -> Limit results to this attribute type
  #   - @search_issue -> Limit results to packages with this issue in the changelog
  #   - @owner_limit -> Limit the amount of owners
  #   - @owner_devel -> Follow devel links for owner search
  # * *Returns* :
  #   - +@results+ -> An array of results
  def search
    # If there is nothing to search for, just return
    return unless params[:search_text]
    # If the search is too short, return too
    if (!@search_text or @search_text.length < 2) && !@search_attrib_type_id && !@search_issue
      flash[:error] = "Search string must contain at least two characters."
      return
    end
    
    if @search_text.starts_with?("obs://")
    # The user entered an OBS-specific RPM disturl, redirect to package source files with respective revision
      flash[:error] = "This disturl does not compute!" unless handle_disturl(@search_text)
      return
    end

    logger.debug "Searching for the string \"#{@search_text}\" in the #{@search_where}'s of #{@search_what}'s"
    if @search_where.length < 1 and !@search_attrib_type_id and !@search_issue
      flash[:error] = "You have to search for #{@search_text} in something. Click the advanced button..."
      return
    end

    @per_page = 20
    search = FullTextSearch.new(text: @search_text,
                                classes: @search_what,
                                attrib_type_id: @search_attrib_type_id,
                                fields: @search_where,
                                issue_name: @search_issue,
                                issue_tracker_name: @search_tracker)
    @results = search.search(:page => params[:page], :per_page => @per_page)
    flash[:notice] = 'Your search did not return any results.' if @results.count < 1
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
      redirect_to :controller => 'package', :action => 'show', :project => disturl_project, :package => disturl_package, :rev => disturl_rev and return true
    end
    logger.debug "Computing disturl #{disturl} failed"
    return false
  end

private

  # This sets the needed defaults and input we've got for instance variables
  #
  # * *Returns* :
  #   - @search_text -> The search string we search for
  #   - @search_what -> Array of result limits
  #   - @search_where -> Array of where we search
  #   - @search_attrib_type_id -> Limit results to this attribute type
  #   - @search_issue -> Limit results to packages with this issue in the changelog
  #   - @owner_limit -> Limit the amount of owners
  #   - @owner_devel -> Follow devel links for owner search
  #   - @results -> An empty array for the results
  #
  def set_parameters
    @search_attrib_type_id = nil
    @search_attrib_type_id = params[:attrib_type_id] unless params[:attrib_type_id].blank?

    @search_issue = nil
    @search_issue = params[:issue].strip unless params[:issue].blank?

    @search_tracker = nil
    @search_tracker = params[:issue_tracker] unless params[:issue_tracker].blank?

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
    @owner_devel = "0" if params[:devel] == "off"
    @owner_devel = "1" if params[:devel] == "on"
  end

  def set_attribute_list
    @attrib_type_list = AttribType.includes(:attrib_namespace).map do |t|
      ["#{t.attrib_namespace.name}:#{t.name}", t['id']]
    end
    @attrib_type_list.sort_by! {|a| a.first }
    @attrib_type_list.unshift(['', ''])
  end

  def set_tracker_list
    @issue_tracker_list = IssueTracker.order(:name).map do |t|
      ["#{t.name} (#{t.description})", t.name]
    end
    @default_tracker = 'bnc'
  end
end
