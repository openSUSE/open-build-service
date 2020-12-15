class Webui::StatusMessagesController < Webui::WebuiController
  # TODO: Remove this when we'll refactor kerberos_auth
  before_action :kerberos_auth
  after_action :verify_authorized

  def new
    authorize StatusMessage
  end

  def create
    status_message = authorize StatusMessage.new(status_message_params)

    if status_message.save
      flash[:success] = 'Status message was successfully created.'
    else
      flash[:error] = "Could not create status message: #{status_message.errors.full_messages.to_sentence}"
    end

    redirect_to(controller: 'main', action: 'index')
  end

  def destroy
    status_message = authorize StatusMessage.find(params[:id])

    if status_message.destroy
      flash[:success] = 'Status message was successfully deleted.'
    else
      flash[:error] = "Could not delete status message: #{status_message.errors.full_messages.to_sentence}"
    end

    redirect_to(controller: 'main', action: 'index')
  end

  def acknowledge
    status_message = authorize StatusMessage.find(params[:id])

    collect_metrics(status_message) if status_message.acknowledge!

    respond_to do |format|
      format.js { render controller: 'status_message', action: 'acknowledge' }
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
end
