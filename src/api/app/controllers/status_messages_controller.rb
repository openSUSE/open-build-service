class StatusMessagesController < ApplicationController
  # TODO: Use Pundit StatusMessagePolicy instead of a mix of Pundit and custom policy code
  before_action :require_admin, only: [:create, :update, :destroy]
  before_action :set_status_message, except: [:index, :create]

  def index
    @status_messages = StatusMessage.limit(params[:limit]).order('created_at DESC').includes(:user)
    @count = @status_messages.size
  end

  def show; end

  def create
    status_message = StatusMessage.from_xml(validate_status_message)
    authorize status_message
    status_message.save!
    render_ok
  end

  def update
    authorize @status_message
    if @status_message.update(validate_status_message)
      render_ok
    else
      render_error message: @status_message.errors.full_messages,
                   status: 400, errorcode: 'invalid_status_message'
    end
  end

  def destroy
    authorize @status_message
    @status_message.destroy
    render_ok
  end

  private

  def set_status_message
    @status_message = StatusMessage.find(params[:id])
  end

  # TODO: make it more robust
  def validate_status_message
    Suse::Validator.validate(:status_message, request.raw_post)
    request.raw_post
  end
end
