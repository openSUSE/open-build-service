class StatusMessagesController < ApplicationController
  before_action :set_status_message, except: %i[index create]
  after_action :verify_authorized, except: %i[index show]
  validate_action update: { method: :put, request: :status_message, response: :status_message }
  validate_action create: { method: :post, request: :status_message, response: :status_message }

  def index
    @status_messages = StatusMessage.limit(params[:limit]).order('created_at DESC').includes(:user)
    @count = @status_messages.size
  end

  def show; end

  def create
    xml_body = Xmlhash.parse(request.raw_post)
    @status_message = StatusMessage.new(xml_body.slice('message', 'severity', 'scope'))
    @status_message.user = User.find_by(login: xml_body['user']) || User.session

    authorize @status_message

    if @status_message.save
      render :show
    else
      render_error message: @status_message.errors.full_messages,
                   status: 400, errorcode: 'invalid_status_message'
    end
  end

  def update
    authorize @status_message

    xml_body = Xmlhash.parse(request.raw_post)
    @status_message.assign_attributes(xml_body.slice('message', 'severity', 'scope'))
    @status_message.user = User.find_by(login: xml_body['user']) || User.session

    if @status_message.save
      render :show
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
end
