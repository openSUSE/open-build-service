class ApidocsController < ApplicationController

  @@apidocsbase = File.expand_path(APIDOCS_LOCATION)+"/"

  def index
    logger.debug "PATH: #{request.path}"
    if ( request.path !~ /\/$/ )
      redirect_to "/apidocs/"
    else
      filename = @@apidocsbase + "index.html"
      if ( !File.exist?( filename ) )
        render :text => "Unable to load API documentation source file", :layout => "rbac"
      else
        render( :file => filename, :layout => "rbac" )
      end
    end
  end

  def method_missing symbol, *args
    file = symbol.to_s
    if ( file =~ /\.(xml|xsd|rng)$/ )
      if File.exist?( @@apidocsbase + file )
        send_file( @@apidocsbase + file, :type => "text/xml",
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
