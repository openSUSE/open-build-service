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

    new_messages = Nokogiri::XML(request.raw_post).root
    @messages = []
    if new_messages.css('message').present?
      # message(s) are wrapped in outer xml tag 'status_messages'
      new_messages.css('message').each do |msg|
        @messages << StatusMessage.create!(message: msg.content, severity: msg['severity'], user: User.current)
      end
    else
      # TODO: make use of a validator
      raise CreatingMessagesError, "no message #{new_messages.to_xml}" if new_messages.name != 'message'
      # just one message, NOT wrapped in outer xml tag 'status_messages'
      @messages << StatusMessage.create!(message: new_messages.content, severity: new_messages['severity'], user: User.current)
    end
    render :index
  end

  def destroy
    # check permissions
    unless permissions.status_message_create
      raise PermissionDeniedError, 'message cannot be deleted, you have not sufficient permissions'
    end

    StatusMessage.find(params[:id]).delete
    render_ok
  end
end
