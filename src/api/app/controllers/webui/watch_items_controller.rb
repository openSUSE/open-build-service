class Webui::WatchItemsController < ApplicationController
  before_action :check_item_and_user, only: [:create]
  before_action :check_item_to_destroy, only: [:destroy]

  # TODO: Add a JSON response that includes item name, url,...
  # or whatever other information that we need in the JS watchlist

  def create
    watch_item = WatchItem.new(item: @item, user: @user)
    respond_to do |format|
      if watch_item.save
        format.json { render json: @user.watch_items }
      else
        format.json { render json: { error: watch_item.errors.to_json, status: :unprocessable_entity } }
      end
    end
  end

  def destroy
    respond_to do |format|
      if @item_to_destroy.destroy
        format.json { render json: @item_to_destroy.user.watch_items }
      else
        format.json { render json: @item_to_destroy.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def check_item_and_user
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
    not_found_response if @item.blank? || @user.blank?
  end

  def check_item_to_destroy
    @item_to_destroy = WatchItem.find(params[:id])
    not_found_response if @item_to_destroy.blank?
  end

  def not_found_response
    respond_to do |format|
      format.json { render json: 'Item not found', status: :unprocessable_entity }
    end
  end
end
