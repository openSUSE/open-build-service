class AnnouncementsController < ApplicationController
  before_action :set_announcement, only: [:show, :update, :destroy]
  # Pundit authorization policies control
  after_action :verify_authorized

  # GET /announcements
  def index
    @announcements = Announcement.all
    authorize @announcements
    render formats: [:xml]
  end

  # GET /announcements/1
  def show
    if @announcement.present?
      authorize @announcement
      respond_to do
        format.xml
      end
    else
      render_error message: 'Unknown announcement',
                   status: 404, errorcode: 'unknown_announcement'
    end
  end

  # POST /announcements
  def create
    @announcement = Announcement.new(announcement_params)
    authorize @announcement
    if @announcement.save
      render_ok
    else
      render :new
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

  #### Non CRUD actions

  #### Non actions methods
  # Use hide_action if they are not private

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_announcement
    @announcement = Announcement.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def announcement_params
    params.slice(:title, :content).permit!
  end
end
