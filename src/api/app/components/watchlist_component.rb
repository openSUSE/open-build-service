class WatchlistComponent < ApplicationComponent
  REMOVE_FROM_WATCHLIST_TEXT = {
    'Package' => 'Remove this package from Watchlist',
    'Project' => 'Remove this project from Watchlist',
    'BsRequest' => 'Remove this request from Watchlist'
  }.freeze

  ADD_TO_WATCHLIST_TEXT = {
    'Package' => 'Watch this package',
    'Project' => 'Watch this project',
    'BsRequest' => 'Watch this request'
  }.freeze

  def initialize(user:, bs_request: nil, package: nil, project: nil)
    super

    @user = user
    @object_to_be_watched = object_to_be_watched(bs_request, package, project)
  end

  private

  def object_to_be_watched(bs_request, package, project)
    return bs_request if bs_request

    # this is a remote project, don't offer watching.
    return unless project.is_a?(Project)

    # there is no package, offer watching the project
    return project unless package

    # maybe package is a multibuild flavor? Try do look up the object of the flavor.
    package = Package.get_by_project_and_name(project, package, { follow_multibuild: true }) if package.is_a?(String)

    # the package is coming via a project link, don't offer watching it.
    return if package.project != project

    package
  end

  def object_to_be_watched_in_watchlist?
    @user.watched_items.exists?(watchable: @object_to_be_watched)
  end

  def add_to_watchlist_text
    ADD_TO_WATCHLIST_TEXT[@object_to_be_watched.class.name]
  end

  def remove_from_watchlist_text
    REMOVE_FROM_WATCHLIST_TEXT[@object_to_be_watched.class.name]
  end

  def toggle_watchable_path
    case @object_to_be_watched
    when Package
      project_package_toggle_watched_item_path(project_name: @object_to_be_watched.project.name, package_name: @object_to_be_watched.name)
    when Project
      project_toggle_watched_item_path(project_name: @object_to_be_watched.name)
    when BsRequest
      toggle_watched_item_request_path(number: @object_to_be_watched.number)
    end
  end

  def projects
    @projects ||= ProjectsForWatchlistFinder.new.call(@user)
  end

  def packages
    @packages ||= PackagesForWatchlistFinder.new.call(@user)
  end

  def bs_requests
    @bs_requests ||= RequestsForWatchlistFinder.new.call(@user)
  end
end
