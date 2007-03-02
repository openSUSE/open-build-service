class MonitorController < ApplicationController


  def index
    get_settings
    if request.post? && ! params[:project].nil? && params[:project] != ""
      redirect_to :project => params[:project]
    else
      @workerstatus = Workerstatus.find :all
      @status_messages = get_status_messages
    end
  end


  def add_message_form
    render :partial => 'add_message_form'
  end


  def save_message
    message = Statusmessage.new(
      :message => params[:message],
      :severity => params[:severity].to_i
    )
    begin
      message.save
    rescue ActiveXML::Transport::ForbiddenError
      @denied = true
    end
    @status_messages = get_status_messages
  end


  def delete_message
    message = Statusmessage.find( :id => params[:id] )
    begin
      message.delete( params[:id] )
    rescue ActiveXML::Transport::ForbiddenError
      @denied = true
    end
    @status_messages = get_status_messages
  end


  def show_more_messages
    @status_messages = get_status_messages 100
  end


  def get_status_messages( limit=nil )
    @max_messages = 4
    limit ||= params[:message_limit]
    limit = @max_messages if limit.nil?
    return Statusmessage.find( :all, :limit => limit )
  end


  def filtered_list
    get_settings
    @workerstatus = Workerstatus.find :all
    render :partial => 'building_table'
  end


  def get_settings
    @project_filter = params[:project]

    # @interval_steps must be > 0:
    # @interval_steps * @max_color + @dead_line minutes
    @interval_steps = 1
    @max_color = 240
    @time_now = Time.now
    @dead_line = 1.hours.ago
  end


end
