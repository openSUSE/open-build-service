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

  def initialize(items:, class_name:, current_object:)
    super

    @items = items
    @class_name = class_name
    @current_object = current_object
    @current_object_class_name = @current_object.class.name
  end

  private

  def list_title
    LIST_TITLE[@class_name]
  end

  def empty_list_text
    EMPTY_LIST_TEXTS[@class_name]
  end

  def current_object_params
    object_type = @current_object.class.name
    case object_type
    when 'Project'
      { type: object_type, name: @current_object.name }
    when 'Package'
      { type: object_type, package_name: @current_object.name, project_name: @current_object.project_name }
    when 'BsRequest'
      { type: object_type, number: @current_object.number }
    end
  end
end
