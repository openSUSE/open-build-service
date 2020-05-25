class StatusMessagesController < ApplicationController
  before_action :require_admin, only: [:create, :destroy]

  def index
    @messages = StatusMessage.alive.limit(params[:limit]).order('created_at DESC').includes(:user)
    @count = @messages.size
  end

  def show
    @message = StatusMessage.find(params[:id])
  end

  def create
    status_message = StatusMessage.from_xml(validate_status_message)

    authorize status_message

    status_message.save!

    render_ok
  end

  def destroy
    status_message = StatusMessage.find(params[:id])
    authorize status_message
    status_message.delete
    render_ok
  end

  private

  # TODO: make it more robust
  def validate_status_message
    Suse::Validator.validate(:status_message, request.raw_post)
    request.raw_post
  end
end
