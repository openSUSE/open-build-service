# This component inherits from WatchlistComponent as the functionality of the icon
# is the same as the links inside the watchlist component one.
class WatchlistIconComponent < WatchlistComponent
  def render?
    @object_to_be_watched.present?
  end
end
