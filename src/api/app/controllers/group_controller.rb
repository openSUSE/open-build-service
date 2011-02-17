#require "rexml/document"

class GroupController < ApplicationController

  def index
    grouplist
  end

  def grouplist
    if !@http_user
      logger.debug "No user logged in, access to group information denied"
      @errorcode = 401
      @summary = "No user logged in, access to group information denied"
      render :template => 'error', :status => 401
      return
    end

    if request.get?
      builder = Builder::XmlMarkup.new( :indent => 2 )
      xml = ""
      if params[:group]
        group = URI.unescape( params[:group] )
        logger.debug "Generating user listing for group  #{group}"
        group = Group.find_by_title( group )
        if group.blank?
          logger.debug "Group is not valid!"
          render_error :status => 404, :errorcode => 'unknown_group',
            :message => "Unknown group: #{group}"
          return
        end
        # list all users of the group
        list = GroupsUser.find(:all, :conditions => ["group_id = ?", group])

        xml = builder.directory( :count => list.length ) do |dir|
          list.each do |g|
            dir.entry( :name => g.user.login )
          end
        end
      else 
        if params[:prefix]
          list = Group.find(:all, :conditions => ["title LIKE ?", params[:prefix] + '%'])
        else
          # list all groups
          list = Group.find(:all)
        end

        xml = builder.directory( :count => list.length ) do |dir|
          list.each do |g|
            dir.entry( :name => g.title )
          end
        end
      end

      render :text => xml, :content_type => "text/xml"
      return
    end

    render_error :status => 404, :errorcode => 'unknown_user',
      :message => "Operation not supported"
  end

  # FIXME/IMPLEMENTME: support operations for adding and remove users to a group
  # TBD: shall we provide meta data for a group, like a description and contact address ?

end
