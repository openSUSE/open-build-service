class RpmController < ApplicationController

  def index
    render_text( "RPMs Index" )
  end

  def buildinfo
    path = "/build/#{params[:project]}/#{params[:repository]}/#{params[:arch]}/#{params[:package]}/_buildinfo"
    if request.post?
      response = Suse::Backend.post_rpm path, request.raw_post
      send_data( response.body, :type => response.fetch( "Content-Type" ), :disposition => "inline" )
    else
      forward_data path
    end
  end

  def file
    repository = params[ :repository ]
    project = params[ :project ]
    arch = params[ :arch ]
    package = params[ :package ]
    file = params[ :file ]

    if ( !repository || !project || !file || !arch )
      render_text( "Error in URL to RPM" )
      return
    end

    path = "/build/" + project + "/" + repository + "/" + arch + "/" + package + 
      "/" + file
    if request.get?
      response = Suse::Backend.get_rpm( path )
      send_data( response.body, :type => response.fetch( "content-type" ),
        :disposition => "inline" )
    end
  end

end
