class Webui::WatchItemsController < ApplicationController
  before_action :find_item_and_user, only: [:create]

  # TODO: Add a JSON response that includes item name, url,...
  # or whatever other information that we need in the JS watchlist

  def create
    respond_to do |format|
      if @item.blank? || @user.blank?
        format.json { render json: 'Item not found', status: :unprocessable_entity }
      else
        watch_item = WatchItem.new(item: @item, user: @user)
        if watch_item.save
          format.json { render json: User.current.watch_items }
        else
          format.json { render json: { error: watch_item.errors.to_json, status: :unprocessable_entity } }
        end
      end
    end
  end

  def destroy
    respond_to do |format|
      item_to_destroy = WatchItem.find(params[:id])
      if item_to_destroy.blank?
        format.json { render json: 'Item not found', status: :unprocessable_entity }
      elsif item_to_destroy.destroy
        format.json { render json: User.current.watch_items }
      else
        format.json { render json: watchlist.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def find_item_and_user
    @item = case params[:item_type]
            when 'project'
              Project.find(params[:item_id])
            when 'package'
              Package.find(params[:item_id])
            when 'request'
              BsRequest.find(params[:item_id])
            end
    @user = if params[:user_id].present?
              User.find(params[:user_id])
            else
              User.current
            end
  end
end
