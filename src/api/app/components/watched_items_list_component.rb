class WatchedItemsListComponent < ApplicationComponent
  LIST_TITLE = {
    'Package' => 'Packages you are watching',
    'Project' => 'Projects you are watching',
    'BsRequest' => 'Requests you are watching'
  }.freeze

  EMPTY_LIST_TEXTS = {
    'Package' => 'There are no packages in the watchlist yet.',
    'Project' => 'There are no projects in the watchlist yet.',
    'BsRequest' => 'There are no requests in the watchlist yet.'
  }.freeze

  def initialize(items:, class_name:)
    super

    @items = items
    @class_name = class_name
  end

  private

  def list_title
    LIST_TITLE[@class_name]
  end

  def empty_list_text
    EMPTY_LIST_TEXTS[@class_name]
  end
end
