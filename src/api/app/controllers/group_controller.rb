#require "rexml/document"

class GroupController < ApplicationController

  before_filter :have_login

  def index
    valid_http_methods :get

    if params[:login]
      user = User.get_by_login(params[:login])
      list = user.groups
    else
      list = Group.find(:all)
    end
    if params[:prefix]
      list = list.find_all{|l| l.match(/^#{params[:prefix]}/)}
    end

    builder = Builder::XmlMarkup.new(:indent => 2)
    xml = builder.directory(:count => list.length) do |dir|
      list.each {|group| dir.entry(:name => group.title)}
    end
    render :text => xml, :content_type => "text/xml"
  end

  # OBSOLETE with 3.0
  def grouplist
    valid_http_methods :get

    builder = Builder::XmlMarkup.new(:indent => 2)
    xml = ""
    if params[:title]
      group = URI.unescape(params[:title])
      logger.debug "Generating user listing for group  #{group}"
      group = Group.find_by_title( group )
      unless group
        render_error :status => 404, :errorcode => 'unknown_group', :message => "Group is not existing" 
        return
      end
      # list all users of the group
      list = GroupsUser.find(:all, :conditions => ["group_id = ?", group])
      xml = builder.directory( :count => list.length ) do |dir|
        list.each {|g| dir.entry( :name => g.user.login)}
      end
    else
      # list all groups
      list = Group.find(:all)
      xml = builder.directory( :count => list.length ) do |dir|
        list.each {|g| dir.entry( :name => g.title )}
      end
    end

    render :text => xml, :content_type => "text/xml" and return
  end

  def show
    valid_http_methods :get
    required_parameters :title

    @group = Group.get_by_title( params[:title] )
    @involved_users = GroupsUser.find(:all, :conditions => ["group_id = ?", @group])
  end

  private

  # filter to check if a user is logged in
  def have_login
    if !@http_user
      logger.debug "No user logged in, access to group information denied"
      @errorcode = 401
      @summary = "No user logged in, access to group information denied"
      render :template => 'error', :status => 401
      return
    end
  end

end
