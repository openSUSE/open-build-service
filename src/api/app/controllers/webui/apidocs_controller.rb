class Webui::ApidocsController < Webui::WebuiController
  def index
    filename = File.expand_path(CONFIG['apidocs_location']) + '/index.html'
    if File.exist?(filename)
      render file: filename, formats: [:html]
    else
      logger.error "Unable to load apidocs index file from #{CONFIG['apidocs_location']}. Did you create the apidocs?"
      flash[:error] = 'Unable to load API documentation.'
      redirect_back(fallback_location: root_path)
    end
  end

  def file
    # Ensure it really is just a file name, no '/..', etc.
    filename = File.basename(params[:filename])
    file = File.expand_path(File.join(CONFIG['schema_location'], filename))
    if File.exist?(file)
      send_file(file, type: 'text/xml', disposition: 'inline')
    else
      flash[:error] = "File not found: #{params[:filename]}"
      redirect_back(fallback_location: { controller: 'apidocs', action: 'index' })
    end
    return
  end
end
