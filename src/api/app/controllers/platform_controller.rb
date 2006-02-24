require 'opensuse/backend'

class PlatformController < ApplicationController

  def index
    s = ""
    out = Builder::XmlMarkup.new( :target => s )
    out.directory do
      response = Suse::Backend.get( "/platform/" )
      directory = REXML::Document.new( response.body )
      directory.elements.each( "/directory/entry" ) do |entry|
        project_name = entry.attributes[ "name" ]
        if ( project_name )
          entry_response = Suse::Backend.get( "/platform/" + project_name )
          entry = REXML::Document.new( entry_response.body )
          entry.elements.each( "/directory/entry" ) do |e|
            repository_name = e.attributes[ "name" ]
            if ( repository_name )
              out.entry( "name" =>  project_name + "/" + repository_name )
            end
          end
        end
      end
    end

    send_data( s, :type => "text/xml", :disposition => "inline" )    
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
