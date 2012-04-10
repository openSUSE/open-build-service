
class GroupController < ApplicationController

  before_filter :have_login

  def index
    valid_http_methods :get

    if params[:login]
      user = User.get_by_login(params[:login])
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

  def show
    valid_http_methods :get
    required_parameters :title

    @group = Group.get_by_title( params[:title] )
    @involved_users = @group.groups_users.all
  end

  private

  # filter to check if a user is logged in
  def have_login
    raise "extract_user should have made one" unless @http_user
    render_error( message: "Access to group information denied", status: 401 ) if @http_user.login == '_nobody_'
  end

end
