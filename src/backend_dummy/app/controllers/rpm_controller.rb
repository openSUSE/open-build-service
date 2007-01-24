class RpmController < ApplicationController

  def initialize
    @basedir = DATA_DIRECTORY + "/rpm/"
  end

  def index
    render_text( "RPMs Index" )
  end

  def file
    platform = params[ :platform ]
    project = params[ :project ]
    file = params[ :file ]

    if ( !platform || !project || !file )
      render_text( "Error in URL to RPM" )
      return
    end

    base_path = @basedir + project + "/" + platform + "/"
    path = base_path + file
    # FIXME Return error message if file doesn't exist
    if request.get?
      send_file( path )
    end
  end

end
