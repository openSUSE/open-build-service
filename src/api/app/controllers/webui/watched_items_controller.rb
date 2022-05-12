class Webui::WatchedItemsController < Webui::WebuiController
  before_action :require_login
  before_action :check_user_belongs_feature_flag
  before_action :set_watchable

  FLASH_PER_WATCHABLE_TYPE = {
    Package => 'package',
    Project => 'project',
    BsRequest => 'request'
  }.freeze

  def toggle_watched_item
    watched_item = User.session!.watched_items.find_by(watchable: @watchable)

    if watched_item
      watched_item.destroy
      flash[:success] = "Removed #{FLASH_PER_WATCHABLE_TYPE[@watchable.class]} from the watchlist"
    else
      User.session!.watched_items.create(watchable: @watchable)
      flash[:success] = "Added #{FLASH_PER_WATCHABLE_TYPE[@watchable.class]} to the watchlist"
    end

    respond_to do |format|
      format.js
    end
  end

  private

  def set_watchable
    @watchable = if params[:project_name] && params[:package_name]
                   @package = Package.get_by_project_and_name(params[:project_name], params[:package_name])
                 elsif params[:project_name]
                   @project = Project.get_by_name(params[:project_name])
                 elsif params[:number]
                   @bs_request = BsRequest.find_by(number: params[:number])
                 end
  end

  def check_user_belongs_feature_flag
    raise NotFoundError unless Flipper.enabled?(:new_watchlist, User.session)
  end
end
