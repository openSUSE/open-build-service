class AnnouncementsController < ApplicationController
  before_action :set_announcement, only: [:show, :update, :destroy]
  # Pundit authorization policies control
  after_action :verify_authorized

  # GET /announcements
  def index
    @announcements = StatusMessage.announcements
    authorize @announcements
    render formats: [:xml]
  end

  # GET /announcements/1
  def show
    authorize @announcement
    render formats: [:xml], locals: { announcement: @announcement }
  end

  # POST /announcements
  def create
    @announcement = StatusMessage.new(announcement_params)
    authorize @announcement
    if @announcement.save
      render_ok
    else
      render_error message: @announcement.errors.full_messages,
                   status: 400, errorcode: 'invalid_announcement'
    end
  end

  # PATCH/PUT /announcements/1
  def update
    authorize @announcement
    if @announcement.update(announcement_params)
      render_ok
    else
      render_error message: @announcement.errors.full_messages,
                   status: 400, errorcode: 'invalid_announcement'
    end
  end

  # DELETE /announcements/1
  def destroy
    authorize @announcement
    @announcement.destroy
    render_ok
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_announcement
    @announcement = StatusMessage.announcements.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def announcement_params
    xml = Nokogiri::XML(request.raw_post, &:strict)
    title = xml.xpath('//announcement/title').text
    content = xml.xpath('//announcement/content').text
    { message: "#{title} #{content}", severity: 'announcement', user: User.session! }
  end
end
