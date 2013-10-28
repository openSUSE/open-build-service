class GroupController < ApplicationController

  validate_action :groupinfo => { :method => :get, :response => :group }
  validate_action :groupinfo => { :method => :put, :request => :group, :response => :status }
  validate_action :groupinfo => { :method => :delete, :response => :status }

  before_action :require_admin, except: [:index, :show]

  def index
    if params[:login]
      user = User.find_by_login!(params[:login])
      @list = user.groups
    else
      @list = Group.all
    end
    if params[:prefix]
      @list = @list.find_all { |group| group.title.match(/^#{params[:prefix]}/) }
    end
  end

  # DELETE for removing it
  def delete
    group = Group.find_by_title!(params[:title])
    group.destroy
    render_ok
  end

  # GET for showing the group
  def show
    @group = Group.find_by_title!(params[:title])
  end

  # PUT for rewriting it completely including defined user list.
  def update
    group = Group.find_by_title(params[:title])
    if group.nil?
      group = Group.create(:title => params[:title])
    end
    group.update_from_xml(Xmlhash.parse(request.raw_post))
    group.save!

    render_ok
  end

  # POST for editing it, adding or remove users
  def command
    group = Group.find_by_title!(URI.unescape(params[:title]))
    user = User.find_by_login!(params[:userid]) if params[:userid]

    if params[:cmd] == "add_user"
      group.add_user user
    elsif params[:cmd] == "remove_user"
      group.remove_user user
    elsif params[:cmd] == "set_email"
      group.set_email params[:email]
    else
      raise UnknownCommandError.new "cmd must be set to add_user or remove_user"
    end

    render_ok
  end

end
