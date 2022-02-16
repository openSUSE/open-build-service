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

  def initialize(user:, project_name: nil, package_name: nil, bs_request_number: nil)
    super

    @user = user
    @object_to_be_watched = object_to_be_watched(project_name, package_name, bs_request_number)
  end

  private

  # Returns the object that can be added or removed from the watchlist.
  # Returns nil if the current page is not related to any watchable object.
  def object_to_be_watched(project_name, package_name, bs_request_number)
    if package_name
      Package.find_by_project_and_name(project_name, package_name)
    elsif project_name
      Project.find_by(name: project_name)
    elsif bs_request_number
      BsRequest.find_by(number: bs_request_number)
    end
  end

  def object_to_be_watched_in_watchlist?
    !!@user.watched_items.includes(:watchable).find_by(watchable: @object_to_be_watched)
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
      toggle_package_watchable_path(project: @object_to_be_watched.project.name, package: @object_to_be_watched.name)
    when Project
      toggle_project_watchable_path(project: @object_to_be_watched.name)
    when BsRequest
      toggle_request_watchable_path(number: @object_to_be_watched.number)
    end
  end

  def projects
    @projects ||= Project.joins(:watched_items).where(watched_items: { user: @user })
  end

  def packages
    @packages ||= Package.joins(:watched_items).where(watched_items: { user: @user })
  end

  def bs_requests
    @bs_requests ||= BsRequest.joins(:watched_items).where(watched_items: { user: @user })
  end
end
