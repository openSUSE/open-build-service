class AnnouncementsController < ApplicationController
  before_action :set_status_message, only: %i[show update destroy]
  # Pundit authorization policies control
  after_action :verify_authorized

  # GET /announcements
  def index
    @status_messages = StatusMessage.announcements
    @count = @status_messages.size
    authorize @status_messages
    render 'status_messages/index', formats: [:xml]
  end

  # GET /announcements/1
  def show
    authorize @status_message
    render 'status_messages/show', formats: [:xml]
  end

  # POST /announcements
  def create
    status_message = StatusMessage.new(status_message_params)
    authorize status_message
    if status_message.save
      render_ok
    else
      render_error message: status_message.errors.full_messages,
                   status: 400, errorcode: 'invalid_announcement'
    end
  end

  # PATCH/PUT /announcements/1
  def update
    authorize @status_message
    if @status_message.update(status_message_params)
      render_ok
    else
      render_error message: @status_message.errors.full_messages,
                   status: 400, errorcode: 'invalid_announcement'
    end
  end

  # DELETE /announcements/1
  def destroy
    authorize @status_message
    @status_message.destroy
    render_ok
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_status_message
    @status_message = StatusMessage.announcements.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def status_message_params
    xml = Nokogiri::XML(request.raw_post, &:strict)
    title = xml.xpath('//announcement/title').text
    content = xml.xpath('//announcement/content').text
    { message: "#{title} #{content}", severity: 'announcement', user: User.session }
  end
end
