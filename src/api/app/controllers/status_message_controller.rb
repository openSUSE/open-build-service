class StatusMessageController < ApplicationController


  validate_action :new_message => :status_messages

  def index
    redirect_to :controller => "status", :action => "messages"
  end

end
