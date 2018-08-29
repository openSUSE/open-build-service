class StatusMessagesController < ApplicationController
  class PermissionDeniedError < APIError
    setup 403
  end

  class CreatingMessagesError < APIError; end

  def index
    @messages = StatusMessage.alive.limit(params[:limit]).order('created_at DESC').includes(:user)
    @count = @messages.size
  end

  def show
    @messages = [StatusMessage.find(params[:id])]
    @count = 1
    render :index
  end

  def create
    # check permissions
    unless permissions.status_message_create
      raise PermissionDeniedError, 'message(s) cannot be created, you have not sufficient permissions'
    end

    new_messages = ActiveXML::Node.new(request.raw_post)

    if new_messages.has_element?('message')
      # message(s) are wrapped in outer xml tag 'status_messages'
      new_messages.each('message') do |msg|
        save_new_message(msg)
      end
    else
      # TODO: make use of a validator
      raise CreatingMessagesError, "no message #{new_messages.dump_xml}" if new_messages.element_name != 'message'
      # just one message, NOT wrapped in outer xml tag 'status_messages'
      save_new_message(new_messages)
    end
    render_ok
  end

  def destroy
    # check permissions
    unless permissions.status_message_create
      raise PermissionDeniedError, 'message cannot be deleted, you have not sufficient permissions'
    end

    StatusMessage.find(params[:id]).delete
    render_ok
  end

  private

  def save_new_message(msg)
    message = StatusMessage.new
    message.message = msg.to_s
    message.severity = msg.value :severity
    message.user = User.current
    message.save!
  end
end
