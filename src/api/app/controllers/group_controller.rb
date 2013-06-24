
class GroupController < ApplicationController

  validate_action :groupinfo => {:method => :get, :response => :group}
  validate_action :groupinfo => {:method => :put, :request => :group, :response => :status}
  validate_action :groupinfo => {:method => :delete, :response => :status}

  def index
    if params[:login]
      user = User.find_by_login!(params[:login])
      list = user.groups
    else
      list = Group.all
    end
    if params[:prefix]
      list = list.find_all {|group| group.title.match(/^#{params[:prefix]}/)}
    end

    builder = Builder::XmlMarkup.new(:indent => 2)
    xml = builder.directory(:count => list.length) do |dir|
      list.each {|group| dir.entry(:name => group.title)}
    end
    render :text => xml, :content_type => "text/xml"
  end

  # generic function to handle all group related tasks
  # GET for showing the group
  # DELETE for removing it
  # PUT for rewriting it completely including defined user list.
  # POST for editing it, adding or remove users
  def group
    required_parameters :title

    if !@http_user
      logger.debug "No user logged in, permission to groupinfo denied"
      render_error :status => 401, :errorcode => "unknown_user"
      return
    end

    unless request.get? or @http_user.is_admin?
      render_error :status => 403, :errorcode => "group_modification_not_permitted", :message => "Requires admin privileges" 
      return
    end

    if request.delete?
      group = Group.get_by_title(URI.unescape(params[:title]))
      group.destroy
      render_ok
      return

    elsif request.put?

      group = Group.find_by_title(params[:title])
      if group.nil?
        group = Group.create(:title => params[:title])
      end
      group.update_from_xml(Xmlhash.parse(request.body.read))
      group.save!

      render_ok
      return
    elsif request.post?
      group = Group.get_by_title(URI.unescape(params[:title]))

      if params[:cmd] == "add_user"
        user = User.find_by_login!(params[:userid])
        group.add_user user
      elsif params[:cmd] == "remove_user"
        user = User.find_by_login!(params[:userid])
        group.remove_user user
      else
        render_error :status => 400, :errorcode => "unknown_command", :message => "cmd must be set to add_user or remove_user" 
        return
      end

      render_ok
      return
    end

    # GET ...
    group = Group.get_by_title(URI.unescape(params[:title]))
    render :text => group.render_axml, :content_type => 'text/xml'
  end

end
