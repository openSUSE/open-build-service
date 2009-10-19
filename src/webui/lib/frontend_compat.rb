class FrontendCompat
  def initialize
  end

  def logger
    ActiveXML::Config.logger
  end

  def cmd_package( project, package, cmd, opt={} )
    extraparams = ''
    extraparams << "&repo=#{CGI.escape opt[:repo]}" if opt[:repo]
    extraparams << "&arch=#{CGI.escape opt[:arch]}" if opt[:arch]

    logger.debug "CMD_PACKAGE #{cmd} ; extraparams = #{extraparams}"
    transport.direct_http URI("https:///source/#{project}/#{package}?cmd=#{cmd}#{extraparams}"),
      :method => "POST", :data => ""
  end

  #  trigger rebuild
  #  opt takes keys: project(needed), repository, arch
  #  missing project raises RuntimeError
  def rebuild( opt={} )
    raise RuntimeError, "project name missing" unless opt.has_key? :project
    logger.debug "--> rebuild: #{opt.inspect}"
    path = "/build/#{opt[:project]}?cmd=rebuild"
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
    path = '/source'
    path += "/#{opt[:project]}" if opt[:project]
    path += "/#{opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{opt[:filename]}" if opt[:filename]
    logger.debug "--> get_source path: #{path}"
    
    transport.direct_http URI("https://#{path}")
  end

  def put_file( data, opt={} )
    transport.direct_http URI("https:///source/#{opt[:project]}/#{opt[:package]}/#{opt[:filename]}"),
      :method => "PUT", :data => data
  end

  def delete_package( opt={} )
    logger.debug "deleting: #{opt.inspect}"
    transport.direct_http URI("https:///source/#{opt[:project]}/#{opt[:package]}"), :method => "DELETE"
  end

  def delete_file( opt={} )
    logger.debug "starting to delete file, opt: #{opt.inspect}"
    transport.direct_http URI("https:///source/#{opt[:project]}/#{opt[:package]}/#{opt[:filename]}"),
      :method => "DELETE"
  end

  def get_log_chunk( project, package, repo, arch, offset=0 )
    path = "/build/#{project}/#{repo}/#{arch}/#{package}/_log?nostream=1&start=#{offset}"
    transport.direct_http URI("https://#{path}")
  end

  def transport
    @transport ||= ActiveXML::Config::transport_for( :project )
  end
end
