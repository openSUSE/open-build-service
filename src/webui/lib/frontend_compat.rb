class FrontendCompat

  def initialize
    @url_prefix = CONFIG['api_relative_url_root'] || ""
  end

  def logger
    ActiveXML::Config.logger
  end

  def cmd_package( project, package, cmd, opt={} )
    extraparams = ''
    extraparams << "&repo=#{CGI.escape opt[:repo]}" if opt[:repo]
    extraparams << "&arch=#{CGI.escape opt[:arch]}" if opt[:arch]

    logger.debug "CMD_PACKAGE #{cmd} ; extraparams = #{extraparams}"
    transport.direct_http URI("https://#{@url_prefix}/source/#{project}/#{package}?cmd=#{cmd}#{extraparams}"),
      :method => "POST", :data => ""
  end

  #  opt takes keys: project(needed), repository, arch
  #  missing project raises RuntimeError
  def cmd( command, opt={} )
    raise RuntimeError, "project name missing" unless opt.has_key? :project
    logger.debug "--> rebuild: #{opt.inspect}"
    path = "#{@url_prefix}/build/#{opt[:project]}?cmd=#{command}"
    opt.delete :project

    valid_opts = %(project package repository arch code)
    opt.each do |key, val|
      raise RuntimeError, "unknown method parameter #{key}" unless valid_opts.include? key.to_s
      path += "&#{key.to_s}=#{CGI.escape val}"
    end
    #logger.debug "### rebuild path: #{path}"
    transport.direct_http URI("https://#{path}"), :method => "POST", :data => ""
  end

  def get_source( opt={} )
    logger.debug "--> get_source: #{opt.inspect}"
    path = "#{@url_prefix}/source"
    path += "/#{opt[:project]}" if opt[:project]
    path += "/#{opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{opt[:filename]}" if opt[:filename]
    logger.debug "--> get_source path: #{path}"
    
    transport.direct_http URI("https://#{path}")
  end

  def put_file( data, opt={} )
    path = "#{@url_prefix}/source"
    path += "/#{opt[:project]}" if opt[:project]
    path += "/#{opt[:package]}" if opt[:project] && opt[:package]
    path += URI.escape("/#{opt[:filename]}") if opt[:filename]
    path += URI.escape("?comment=#{opt[:comment]}") if !opt[:comment].blank?
    transport.direct_http URI("https://#{path}"),
      :method => "PUT", :data => data, :timeout => 500
  end

  def delete_package( opt={} )
    logger.debug "deleting: #{opt.inspect}"
    transport.direct_http URI("https://#{@url_prefix}/source/#{opt[:project]}/#{opt[:package]}"), 
      :method => "DELETE", :timeout => 500
  end

  def delete_file( opt={} )
    logger.debug "starting to delete file, opt: #{opt.inspect}"
    transport.direct_http URI("https://#{@url_prefix}/source/#{opt[:project]}/#{opt[:package]}/#{opt[:filename]}"),
      :method => "DELETE", :timeout => 500
  end

  def get_log_chunk( project, package, repo, arch, start, theend )
    logger.debug "get log chunk #{start}-#{theend}"
    path = "#{@url_prefix}/build/#{project}/#{repo}/#{arch}/#{package}/_log?nostream=1&start=#{start}&end=#{theend}"
    transport.direct_http URI("https://#{path}")
  end

  def get_size_of_log( project, package, repo, arch)
    logger.debug "get log entry"
    path = "#{@url_prefix}/build/#{project}/#{repo}/#{arch}/#{package}/_log?view=entry"
    data = transport.direct_http URI("https://#{path}")
    if ! data
      return 0
    end
    xml = XML::Parser.string(data).parse.root
    return Integer(xml.find_first('//entry')['size'])
  end

  def transport
    @transport ||= ActiveXML::Config::transport_for( :project )
  end
end
