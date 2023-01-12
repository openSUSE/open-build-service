class Webui::StatusMessagesController < Webui::WebuiController
  # TODO: Remove this when we'll refactor kerberos_auth
  before_action :kerberos_auth
  after_action :verify_authorized, except: [:preview]

  def index
    authorize StatusMessage

    @severity, @communication_scope, @page = index_params.values_at(:severity, :communication_scope, :page)
    @status_messages = StatusMessage.newest.includes(:user).for_severity(@severity).for_communication_scope(@communication_scope).page(@page)

    respond_to do |format|
      format.html
      format.js
    end
  end

  def new
    authorize StatusMessage
  end

  def edit
    @status_message = authorize StatusMessage.find(params[:id])
  end

  def create
    status_message = authorize StatusMessage.new(status_message_params)

    if status_message.save
      flash[:success] = 'News item was successfully created.'
    else
      flash[:error] = "Could not create news item: #{status_message.errors.full_messages.to_sentence}"
    end

    redirect_to(action: 'index')
  end

  def update
    status_message = authorize StatusMessage.find(params[:id])

    if status_message.update(status_message_params)
      flash[:success] = 'News item was successfully updated.'
    else
      flash[:error] = "Could not update news item: #{status_message.errors.full_messages.to_sentence}"
    end

    redirect_to(action: 'index')
  end

  def destroy
    status_message = authorize StatusMessage.find(params[:id])

    if status_message.destroy
      flash[:success] = 'News item was successfully deleted.'
    else
      flash[:error] = "Could not delete news item: #{status_message.errors.full_messages.to_sentence}"
    end

    redirect_back_or_to({ action: 'index' })
  end

  def acknowledge
    status_message = authorize StatusMessage.find(params[:id])

    collect_metrics(status_message) if status_message.acknowledge!

    respond_to do |format|
      format.js { render controller: 'status_message', action: 'acknowledge' }
    end
  end

  def preview
    markdown = helpers.render_as_markdown(status_message_params[:message])
    respond_to do |format|
      format.json { render json: { markdown: markdown } }
    end
  end

  private

  def authorize(*args, **kwargs)
    super(*args, policy_class: Webui::StatusMessagePolicy, **kwargs)
  end

  def collect_metrics(status_message)
    RabbitmqBus.send_to_bus('metrics', "user.acknowledged_status_message status_message_id=#{status_message.id}")
  end

  def status_message_params
    params.require(:status_message).permit(:message, :severity, :communication_scope).merge(user: User.session)
  end

  def index_params
    params.permit(:severity, :communication_scope, :page)
  end
end
