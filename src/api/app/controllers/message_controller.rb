class MessageController < ApplicationController

  validate_action :index => {:method => :get, :response => :messages}
  validate_action :index => {:method => :put, :request => :message, :response => :status}

  def index

    # get project and package if params are set
    @project = Project.find_by_name params[:project]
    @package = Package.where('name=? AND db_project_id=?', params[:package], @project.id).first if @project

    if request.get?

      if id = params[:id]
        @messages = [ Message.find(id) ]
      elsif @package
        @messages = @package.messages
      elsif @project
        @messages = @project.messages
      else
        @messages = Message.limit(params[:limit]).order('created_at DESC').all
      end

    elsif request.put?

      check_permissions or return
      new_msg = ActiveXML::Node.new( request.raw_post )
      begin
        msg = Message.new
        msg.text = new_msg.to_s
        msg.severity = new_msg.severity
        msg.send_mail = new_msg.send_mail
        msg.private = new_msg.private
        msg.user = @http_user
        if @package
          @package.messages += [msg]
        elsif @project
          @project.messages += [msg]
        else
          raise ArgumentError, "must give either project or package"
        end
        msg.save
        render_ok
      rescue ArgumentError => e
        render_error :status => 400, :errorcode => "error creating message",
          :message => e.message
      end

    elsif request.delete?

      check_permissions or return
      begin
        Message.find( params[:id] ).delete
        render_ok
      rescue
        render_error :status => 400, :errorcode => "error deleting message",
          :message => "error deleting message - id not found or not given"
      end

    else

      render_error :status => 400, :errorcode => "forbidden method",
        :message => "only PUT, GET or DELETE method allowed for this action"

    end
  end


private
  def check_permissions
    if ( @package and not permissions.package_change? @package.name, @project.name ) or
       ( @project and not permissions.project_change? @project.name )
      render_error :status => 403, :errorcode => "permission denied",
        :message => "message cannot be created, insufficient permissions"
      return nil
    end
    return true
  end

end
