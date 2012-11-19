class ApidocsController < ApplicationController

  # Apidocs is insensitive static information, no login needed therefore
  skip_before_filter :extract_user

  def root
    redirect_to action: :index
  end

  def index
    logger.debug "PATH: #{request.path}"
    filename = File.expand_path(CONFIG['apidocs_location']) + "/index.html"
    if ( !File.exist?( filename ) )
      render_error status: 404, message: "Unable to load API documentation source file"
    else
      render :file => filename
    end
  end

  def file
    file = params[:filename]
    if ( file =~ /\.(xml|xsd|rng)$/ )
      file = File.expand_path( File.join(CONFIG['schema_location'], file) )
      if File.exist?( file )
        send_file( file, :type => "text/xml",
          :disposition => "inline" )
      else
        render_error :status => 404, :errorcode => 'file_not_found', :message => 'file was not found'
      end
    else
      render_error :status => 404, :errorcode => 'unknown_file_type', :message => 'file should end with xml,xsd or rng'
    end
    return
  end

end
