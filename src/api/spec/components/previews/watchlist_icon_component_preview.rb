class WatchlistIconComponentPreview < ViewComponent::Preview
  # All the examples in this preview use project as watched item. It works the same with package and request.
  # Preview at http://HOST:PORT/rails/view_components/watchlist_icon_component/icon_to_add
  def icon_to_add
    remove_from_watchlist(item)
    render(WatchlistIconComponent.new(user, item))
  end

  # Preview at http://HOST:PORT/rails/view_components/watchlist_icon_component/icon_to_remove
  def icon_to_remove
    add_to_watchlist(item)
    render(WatchlistIconComponent.new(user, item))
  end

  private

  def user
    User.first
  end

  def item
    Project.first
  end

  def in_watchlist?(item)
    user.watched_items.where(watchable: item).present?
  end

  def remove_from_watchlist(item)
    return unless in_watchlist?(item)

    user.watched_items.find_by(watchable: item).destroy
  end

  def add_to_watchlist(item)
    return item if in_watchlist?(item)

    user.watched_items.create(watchable: item)
  end
end
