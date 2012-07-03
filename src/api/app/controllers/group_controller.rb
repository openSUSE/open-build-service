
class GroupController < ApplicationController

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

  def show
    valid_http_methods :get
    required_parameters :title

    @group = Group.find_by_title!( params[:title] )
    @involved_users = @group.groups_users.all
  end

end
