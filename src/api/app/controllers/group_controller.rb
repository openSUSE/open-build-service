
class GroupController < ApplicationController

  validate_action :groupinfo => {:method => :get, :response => :group}
  validate_action :groupinfo => {:method => :put, :request => :group, :response => :status}
  validate_action :groupinfo => {:method => :delete, :response => :status}

  def index
    valid_http_methods :get

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

  def groupinfo
    valid_http_methods :get, :put, :delete
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
    end

    if request.put?

      group = Group.find_by_title(params[:title])
      if group.nil?
        group = Group.create(:title => params[:title])
      end
      group.update_from_xml(Xmlhash.parse(request.body.read))
      group.save!

      render_ok
      return
    end

    group = Group.get_by_title(URI.unescape(params[:title]))
    render :text => group.render_axml, :content_type => 'text/xml'
  end

end
