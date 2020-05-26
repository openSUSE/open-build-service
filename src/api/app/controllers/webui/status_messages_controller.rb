class Webui::StatusMessagesController < Webui::WebuiController
  # permissions.status_message_create
  before_action :require_admin, only: [:destroy, :create]

  def create
    # TODO: make use of permissions.status_message_create
    status_message = StatusMessage.new(user: User.session!,
                                       message: params[:status_message][:message],
                                       severity: params[:status_message][:severity],
                                       communication_scope: params[:status_message][:communication_scope])

    if status_message.save
      flash[:success] = 'Status message was successfully created.'
    else
      flash[:error] = "Could not create status message: #{status_message.errors.full_messages.to_sentence}"
    end

    redirect_to(controller: 'main', action: 'index')
  end

  def destroy
    status_message = StatusMessage.find(params[:id])

    if status_message.delete
      flash[:success] = 'Status message was successfully deleted.'
    else
      flash[:error] = "Could not delete status message: #{status_message.errors.full_messages.to_sentence}"
    end

    redirect_to(controller: 'main', action: 'index')
  end

  def acknowledge
    status_message = StatusMessage.find(params[:id])
    unless status_message.acknowledge!
      RabbitmqBus.send_to_bus('metrics', "user.acknowledged_status_message status_message_id=#{status_message.id}")
      flash.now[:error] = "Could not accept status message: #{status_message.errors.full_messages.to_sentence}"
    end
    respond_to do |format|
      format.js { render controller: 'status_message', action: 'acknowledge' }
    end
  end
end
