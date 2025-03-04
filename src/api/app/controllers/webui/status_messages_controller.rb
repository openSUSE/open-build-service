class Webui::StatusMessagesController < Webui::WebuiController
  before_action :require_login, only: :acknowledge
  before_action :require_staff, except: :acknowledge
  before_action :set_status_message, only: %i[edit update destroy acknowledge]
  after_action :verify_authorized, only: %i[create update destroy]

  def index
    @severity, @communication_scope, @page = index_params.values_at(:severity, :communication_scope, :page)
    @status_messages = StatusMessage.newest.includes(:user).for_severity(@severity).for_communication_scope(@communication_scope).page(@page)

    respond_to do |format|
      format.html
      format.js
    end
  end

  def new; end

  def edit; end

  def create
    status_message = StatusMessage.new(status_message_params)
    authorize status_message

    if status_message.save
      flash[:success] = 'News item was successfully created.'
    else
      flash[:error] = "Could not create news item: #{status_message.errors.full_messages.to_sentence}"
    end

    redirect_to(action: 'index')
  end

  def update
    authorize @status_message

    if @status_message.update(status_message_params)
      flash[:success] = 'News item was successfully updated.'
    else
      flash[:error] = "Could not update news item: #{@status_message.errors.full_messages.to_sentence}"
    end

    redirect_to(action: 'index')
  end

  def destroy
    authorize @status_message

    if @status_message.destroy
      flash[:success] = 'News item was successfully deleted.'
    else
      flash[:error] = "Could not delete news item: #{@status_message.errors.full_messages.to_sentence}"
    end

    redirect_back_or_to({ action: 'index' })
  end

  def acknowledge
    @status_message.acknowledge!
    respond_to do |format|
      format.js { render 'acknowledge' }
    end
  end

  def preview
    markdown = helpers.render_as_markdown(status_message_params[:message])
    respond_to do |format|
      format.json { render json: { markdown: markdown } }
    end
  end

  private

  def require_staff
    return if User.possibly_nobody.admin? || User.possibly_nobody.staff?

    flash[:error] = 'Requires staff privileges'
    redirect_back_or_to({ controller: 'main', action: 'index' })
  end

  def set_status_message
    @status_message = StatusMessage.find(params[:id])
  end

  def status_message_params
    params.require(:status_message).permit(:message, :severity, :communication_scope).merge(user: User.session)
  end

  def index_params
    params.permit(:severity, :communication_scope, :page)
  end
end
