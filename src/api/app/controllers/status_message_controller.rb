class StatusMessageController < ApplicationController


  validate_action :new_message => :status_messages


  def index
    if request.get?

      @messages = StatusMessage.find :all, :limit => params[:limit]

    elsif request.put?

      new_messages = ActiveXML::Base.new( request.raw_post )

      begin
        new_messages.each_message do |msg|
          message = StatusMessage.new
          message.message = msg.to_s
          message.user = @http_user
          message.save
        end
        render_ok
      rescue
        render_error :status => 400, :errorcode => "error creating message(s)",
        :message => "message(s) cannot be created"
      end

    elsif request.delete?

      # TODO: implement delete

    else

      render_error :status => 400, :errorcode => "only_put_or_get_method_allowed",
        :message => "only PUT or GET method allowed for this action"
      return

    end
  end


end
