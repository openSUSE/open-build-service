class ApidocsController < ApplicationController

  # Apidocs is insensitive static information, no login needed therefore
  skip_before_filter :extract_user

  def index
    logger.debug "PATH: #{request.path}"
    filename = File.expand_path(CONFIG['apidocs_location']) + "/index.html"
    if ( !File.exist?( filename ) )
      render :text => "Unable to load API documentation source file", :layout => "rbac"
    else
      render( :file => filename, :layout => "rbac" )
    end
  end

  def file
    file = params[:file]
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
