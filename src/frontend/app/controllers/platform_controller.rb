require 'opensuse/backend'

class PlatformController < ApplicationController

  def index
    repolist = DbProject.get_repo_list

    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.directory( :count => repolist.length ) do |dir|
      repolist.each do |repo|
        dir.entry( :name => repo )
      end
    end

    render :text => xml, :content_type => "text/xml"
  end
  
  def project
    forward_data( "/platform/" + params[:project] )
  end
  
  def repository
    repository = params[ :repository ]
    project = params[ :project ]

    if ( !repository || !project )
      redirect_to :index
      return
    else
      path = "/platform/" + project + "/" + repository

      if request.get?
        forward_data( path )
        return
      elsif request.put?
        response = Suse::Backend.put( path, request.raw_post )
        case response
        when Net::HTTPSuccess, Net::HTTPRedirection
          render_text( "Ok" )
          return
        else
          render_text( "Error: " + response.error! )
          return
        end
      end
    end
  end

end
