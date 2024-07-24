class Webui::SearchController < Webui::WebuiController
  before_action :set_attribute_list
  before_action :set_tracker_list
  before_action :set_parameters, except: :issue
  before_action :set_page, only: %i[index issue]

  def index
    search
  end

  def owner
    # If the search is too short, return
    return if @search_text.blank?

    if @search_text && @search_text.length < 2
      flash[:error] = 'Search string must contain at least two characters.'
      return
    end

    @results = OwnerSearch::Assignee.new(limit: @owner_limit.to_s, devel: @owner_devel.to_s).for(@search_text)
    flash[:notice] = 'Your search did not return any results.' if @results.empty?
  end

  def issue
    return unless params[:issue] && params[:issue_tracker]

    search_issue
    search_what

    if @search_issue.blank?
      flash[:error] = 'Issue ID can not be empty.'
      return
    end

    @per_page = 20
    full_text_search = FullTextSearch.new(classes: @search_what,
                                          issue_name: @search_issue,
                                          issue_tracker_name: @search_tracker)
    @results = perform_search(full_text_search: full_text_search)
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
    @search_attrib_type_id = Integer.try_convert(params[:attrib_type_id]) if params[:attrib_type_id].present?

    search_issue

    @search_text = ''
    @search_text = params[:search_text].strip if params[:search_text].present?
    @search_text = @search_text.delete("'[]\n")

    search_what

    @search_where = []
    @search_where << 'name' if params[:name] == '1'
    @search_where << 'title' if params[:title] == '1'
    @search_where << 'description' if params[:description] == '1'

    @owner_limit = nil
    @owner_limit = 1 if params[:limit].blank?
    @owner_limit ||= Integer.try_convert(params[:limit]) || 1

    @owner_devel = nil
    @owner_devel = '0' if params[:devel] == 'off'
    @owner_devel = '1' if params[:devel] == 'on'
  end

  def search_issue
    @search_issue = params[:issue].presence.try(:strip)

    @search_tracker = params[:issue_tracker].presence
  end

  def search_what
    @search_what = []
    @search_what << 'package' if params[:search_for].in?(%w[0 2])
    @search_what << 'project' if params[:search_for].in?(%w[0 1])
  end

  def set_attribute_list
    @attrib_type_list = AttribType.includes(:attrib_namespace).map do |t|
      ["#{t.attrib_namespace.name}:#{t.name}", t['id']]
    end
    @attrib_type_list.sort_by!(&:first)
    @attrib_type_list.unshift(['', ''])
  end

  def set_tracker_list
    @issue_tracker_list = IssueTracker.order(:name).map do |t|
      ["#{t.name} (#{t.description})", t.name]
    end
    @default_tracker = ::Configuration.default_tracker
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
    if (!@search_text || @search_text.length < 2) && !@search_attrib_type_id && !@search_issue
      flash[:error] = 'Search string must contain at least two characters.'
      return
    end

    # request number when string starts with a #
    if @search_text.starts_with?('#') && @search_text[1..].to_i.positive?
      redirect_to controller: 'request', action: 'show', number: @search_text[1..]
      return
    end

    # The user entered an OBS-specific RPM disturl, redirect to package source files with respective revision
    if @search_text.starts_with?('obs://')
      disturl_project, _, disturl_pkgrev = @search_text.split('/')[3..5]
      disturl_rev, disturl_package = disturl_pkgrev.split('-', 2) unless disturl_pkgrev.nil?
      if disturl_project.present? && disturl_package.present? && Package.exists_by_project_and_name(disturl_project, disturl_package, follow_multibuild: true)
        redirect_to controller: 'package', action: 'show', project: disturl_project, package: disturl_package, rev: disturl_rev
      else
        redirect_back_or_to root_path, notice: 'Sorry, this disturl does not compute...'
      end
      return
    end

    logger.debug "Searching for the string \"#{@search_text}\" in the #{@search_where}'s of #{@search_what}'s"

    @per_page = 20
    full_text_search = FullTextSearch.new(text: @search_text,
                                          classes: @search_what,
                                          attrib_type_id: @search_attrib_type_id,
                                          fields: @search_where,
                                          issue_name: @search_issue,
                                          issue_tracker_name: @search_tracker)
    @results = perform_search(full_text_search: full_text_search)
  end

  def perform_search(full_text_search:)
    results = full_text_search.search(page: @page, per_page: @per_page)
    begin
      # ThinkingSphinx exceptions are triggered  when `results` is accessed.
      flash.now[:notice] = 'Your search did not return any results.' if results.empty?
    rescue ThinkingSphinx::OutOfBoundsError
      # Repeat the query with @page set to 1.
      @page = 1
      results = perform_search(full_text_search: full_text_search)
    rescue ThinkingSphinx::SphinxError => e
      flash.now[:error] = "There has been an error performing the search. We're working to fix it. Please, try again later."
      Airbrake.notify(e)
      results = []
    end
    results
  end

  def set_page
    @page = if params[:page].present? && params[:page] =~ /\A\d+\z/
              params[:page]
            else
              1
            end
  end
end
