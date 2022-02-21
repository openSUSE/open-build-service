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

  def initialize(user:, project: nil, package: nil, bs_request: nil)
    super

    @user = user
    # NOTE: the order of the array is important, when project and packge are both present we ensure it takes package.
    @object_to_be_watched = [bs_request, package, project].compact.first
  end

  private

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
      toggle_package_watched_items_path(project: @object_to_be_watched.project.name, package: @object_to_be_watched.name)
    when Project
      toggle_project_watched_items_path(project: @object_to_be_watched.name)
    when BsRequest
      toggle_request_watched_items_path(number: @object_to_be_watched.number)
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
