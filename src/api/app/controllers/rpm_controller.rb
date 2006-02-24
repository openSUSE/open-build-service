class RpmController < ApplicationController

  def index
    render_text( "RPMs Index" )
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

    path = "/rpm/" + project + "/" + repository + "/" + arch + "/" + package + 
      "/" + file
    if request.get?
      response = Suse::Backend.get_rpm( path )
      send_data( response.body, :type => response.fetch( "content-type" ),
        :disposition => "inline" )
    end
  end

end
