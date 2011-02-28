#require "rexml/document"

class GroupController < ApplicationController

  before_filter :have_login

  def index
    valid_http_methods :get

    if params[:prefix]
      list = Group.find(:all, :conditions => ["title LIKE ?", params[:prefix] + '%'])
    else
      list = Group.find(:all)
    end

    builder = Builder::XmlMarkup.new(:indent => 2)
    xml = builder.directory(:count => list.length) do |dir|
      list.each {|group| dir.entry(:name => group.title)}
    end
    render :text => xml, :content_type => "text/xml"
  end

  def show
    valid_http_methods :get, :put

    unless params[:title]
      render_error :status => 400, :errorcode => 'missing_parameters', :message => "Missing parameter 'title'" and return
    end
    title = URI.unescape(params[:title])

    if request.get?
      logger.debug "Generating group from parameter #{title}"
      @render_group = Group.find_by_title(title)
      if @render_group.blank?
        logger.debug "Group is not valid!"
        render_error :status => 404, :errorcode => 'unknown_group', :message => "Unknown group: #{title}"
      else
        render :text => @render_group.render_axml(), :content_type => "text/xml"
      end
    elsif request.put?
      unless @http_user.is_admin?
        render_error :status => 403, :errorcode => 'change_group_no_permission',
          :message => "No permission to change group for user #{@http_user.login}" 
        return
      end

      group = Group.find_by_title(title)
      if group.nil?
        group = Group.create(:title => title)
      end

      xml = REXML::Document.new(request.raw_post)
      logger.debug("XML: #{request.raw_post}")
      group.title = xml.elements["/group/title"].text
      group.save!
      render_ok
    end
  end

  def users
    valid_http_methods :get

    unless params[:title]
      render_error :status => 400, :errorcode => 'missing_parameters', :message => "Missing parameter 'title'" 
      return
    end

    group = Group.find_by_title(URI.unescape(params[:title]))
    unless group
      render_error :status => 404, :errorcode => 'unknown_group', :message => "Group is not existing" 
      return
    end
    list = GroupsUser.find(:all, :conditions => ["group_id = ?", group])
    builder = Builder::XmlMarkup.new(:indent => 2)
    xml = builder.directory(:count => list.length) do |dir|
      list.each {|group| dir.entry(:name => group.user.login)}
    end
    render :text => xml, :content_type => "text/xml"
  end

  def grouplist
    valid_http_methods :get

    if request.get?
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

    render_error :status => 404, :errorcode => 'unknown_user', :message => "Operation not supported"
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
