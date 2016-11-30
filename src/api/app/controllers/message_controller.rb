class MessageController < ApplicationController
  validate_action show: {response: :messages}
  validate_action list: {response: :messages}
  validate_action update: {request: :message, response: :status}

  before_action :check_project_and_package
  before_action :check_permissions, only: [:delete, :update]

  def check_project_and_package
    # get project and package if params are set
    if params[:project]
      @project = Project.find_by_name! params[:project]
      if params[:package]
        @package = @project.packages.find_by_name! params[:package]
      end
    end
  end

  def list
    if @package
      @messages = @package.messages
    elsif @project
      @messages = @project.messages
    else
      @messages = Message.limit(params[:limit]).order('created_at DESC')
    end
    render partial: 'messages'
  end

  def show
    @messages = [Message.find(params[:id])]
    render partial: 'messages'
  end

  def delete
    Message.find(params[:id]).delete
    render_ok
  end

  def update
    new_msg = ActiveXML::Node.new(request.raw_post)
    begin
      msg = Message.new
      msg.text = new_msg.to_s
      msg.severity = new_msg.value('severity')
      msg.send_mail = new_msg.value('send_mail')
      msg.private = new_msg.value('private')
      msg.user = @http_user
      if @package
        @package.messages += [msg]
      elsif @project
        @project.messages += [msg]
      else
        raise ArgumentError, 'must give either project or package'
      end
      msg.save
      render_ok
    rescue ArgumentError => e
      render_error status: 400, errorcode: 'error creating message',
                   message: e.message
    end
  end

  private

  def check_permissions
    if (@package && !permissions.package_change?(@package.name, @project.name)) ||
        (@project && !permissions.project_change?(@project.name))
      render_error status: 403, errorcode: 'permission denied',
                   message: 'message cannot be created, insufficient permissions'
      return nil
    end
    true
  end
end
