class Webui::WatchedItemsController < Webui::WebuiController
  before_action :require_login
  before_action :check_user_belongs_feature_flag
  before_action :set_item

  FLASH_PER_WATCHABLE_TYPE = {
    Package => 'package',
    Project => 'project',
    BsRequest => 'request'
  }.freeze

  def toggle
    watched_item = User.session!.watched_items.find_by(watchable: @item)

    if watched_item
      watched_item.destroy
      flash[:success] = "Removed #{FLASH_PER_WATCHABLE_TYPE[@item.class]} from the watchlist"
    else
      User.session!.watched_items.create(watchable: @item)
      flash[:success] = "Added #{FLASH_PER_WATCHABLE_TYPE[@item.class]} to the watchlist"
    end

    redirect_back(fallback_location: root_path)
  end

  private

  def set_item
    @item = if params[:package]
              Package.find_by_project_and_name(params[:project], params[:package])
            elsif params[:project]
              Project.find_by(name: params[:project])
            elsif params[:number]
              BsRequest.find_by(number: params[:number])
            end
  end

  def check_user_belongs_feature_flag
    raise NotFoundError unless Flipper.enabled?(:new_watchlist, User.session)
  end
end
