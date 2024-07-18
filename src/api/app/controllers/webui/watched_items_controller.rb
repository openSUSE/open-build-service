class Webui::WatchedItemsController < Webui::WebuiController
  before_action :require_login
  before_action :set_watchable
  before_action :set_current_object
  skip_before_action :fetch_watchlist_items, only: :toggle_watched_item

  FLASH_PER_WATCHABLE_TYPE = {
    Package => 'package',
    Project => 'project',
    BsRequest => 'request'
  }.freeze

  def toggle_watched_item
    watched_item = User.session.watched_items.find_by(watchable: @watchable)

    if watched_item
      watched_item.destroy
      flash[:success] = "Removed #{FLASH_PER_WATCHABLE_TYPE[@watchable.class]} from the watchlist"
    else
      User.session.watched_items.create(watchable: @watchable)
      flash[:success] = "Added #{FLASH_PER_WATCHABLE_TYPE[@watchable.class]} to the watchlist"
    end

    fetch_watchlist_items

    respond_to do |format|
      format.js
    end
  end

  private

  def set_watchable
    if params[:project_name]
      @project = Project.get_by_name(params[:project_name])
      @package = Package.get_by_project_and_name(params[:project_name], params[:package_name]) if params[:package_name]
    elsif params[:number]
      @bs_request = BsRequest.find_by(number: params[:number])
    end

    @watchable = @package || @project || @bs_request
  end

  def set_current_object
    params[:current_object] ||= {}
    object_type = params[:current_object][:type]
    @current_object = case object_type
                      when 'BsRequest'
                        BsRequest.find_by(number: params[:current_object][:number])
                      when 'Project'
                        Project.get_by_name(params[:current_object][:name])
                      when 'Package'
                        current_object = params[:current_object]
                        Package.get_by_project_and_name(current_object[:project_name], current_object[:package_name])
                      end

    @current_object = @watchable if @current_object.nil?
  end
end
