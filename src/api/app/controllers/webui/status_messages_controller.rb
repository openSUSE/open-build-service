class Webui::StatusMessagesController < Webui::WebuiController
  # permissions.status_message_create
  before_action :require_admin, only: [:destroy, :create]

  def create
    status_message = if params[:severity].try(:to_sym) == :announcement
                       Announcement.new(message: params[:message], communication_scope: params[:communication_scope])
                     else
                       # TODO: make use of permissions.status_message_create
                       StatusMessage.new(message: params[:message], severity: params[:severity],
                                         communication_scope: params[:communication_scope], user: User.session!)
                     end

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
end
