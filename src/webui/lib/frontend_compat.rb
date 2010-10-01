class FrontendCompat

  def esc(str)
    CGI.escape str.to_s
  end

  def initialize
    @url_prefix = CONFIG['api_relative_url_root'] || ""
  end

  def logger
    ActiveXML::Config.logger
  end

  def source_cmd( cmd, opt={} )
    extraparams = ''
    extraparams << "&repository=#{esc opt[:repository]}" if opt[:repository]
    extraparams << "&arch=#{esc opt[:arch]}" if opt[:arch]
    extraparams << "&flag=#{esc opt[:flag]}" if opt[:flag]
    extraparams << "&status=#{esc opt[:status]}" if opt[:status]

    raise RuntimeError, 'no project given' unless opt[:project]
    logger.debug "SOURCE CMD #{cmd} ; extraparams = #{extraparams}"
    path = "https://#{@url_prefix}/source/#{esc opt[:project].to_s}"
    path += "/#{esc opt[:package].to_s}" if opt[:package]
    path += "?cmd=#{cmd}#{extraparams}"
    
    transport.direct_http URI(path), :method => "POST", :data => ""
  end

  #  opt takes keys: project(needed), repository, arch
  #  missing project raises RuntimeError
  def cmd( command, opt={} )
    raise RuntimeError, "project name missing" unless opt.has_key? :project
    logger.debug "--> #{command}: #{opt.inspect}"
    path = "#{@url_prefix}/build/#{opt[:project]}?cmd=#{command}"
    opt.delete :project

    valid_opts = %(project package repository arch code)
    opt.each do |key, val|
      raise RuntimeError, "unknown method parameter #{key}" unless valid_opts.include? key.to_s
      path += "&#{key.to_s}=#{esc val}"
    end
    transport.direct_http URI("https://#{path}"), :method => "POST", :data => ""
  end

  def get_source( opt={} )
    logger.debug "--> get_source: #{opt.inspect}"
    path = "#{@url_prefix}/source"
    path += "/#{esc opt[:project]}" if opt[:project]
    path += "/#{esc opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{esc opt[:filename]}" if opt[:filename]
    path += "?"
    path += "rev=#{esc opt[:rev]}" if opt[:rev]
    logger.debug "--> get_source path: #{path}"
    
    transport.direct_http URI("https://#{path}")
  end

  def put_file( data, opt={} )
    path = "#{@url_prefix}/source"
    path += "/#{esc opt[:project]}" if opt[:project]
    path += "/#{esc opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{esc opt[:filename]}" if opt[:filename]
    path += "?comment=#{esc opt[:comment]}" unless opt[:comment].blank?
    transport.direct_http URI("https://#{path}"),
      :method => "PUT", :data => data, :timeout => 500
  end

  def do_post( data, opt={} )
    path = "#{@url_prefix}/source"
    path += "/#{esc opt[:project]}" if opt[:project]
    path += "/#{esc opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{esc opt[:filename]}" if opt[:filename]
    path += "?"
    path += "cmd=#{esc opt[:cmd]}" unless opt[:cmd].blank?
    path += "&comment=#{esc opt[:comment]}" unless opt[:comment].blank?
    transport.direct_http URI("https://#{path}"),
      :method => "POST", :data => data, :timeout => 500
  end

  def delete_package( opt={} )
    logger.debug "deleting: #{opt.inspect}"
    transport.direct_http URI("https://#{@url_prefix}/source/#{esc opt[:project]}/#{esc opt[:package]}"), 
      :method => "DELETE", :timeout => 500
  end

  def delete_file( opt={} )
    logger.debug "starting to delete file, opt: #{opt.inspect}"
    transport.direct_http URI("https://#{@url_prefix}/source/#{esc opt[:project]}/#{esc opt[:package]}/#{esc opt[:filename]}"),
      :method => "DELETE", :timeout => 500
  end

  def get_log_chunk( project, package, repo, arch, start, theend )
    logger.debug "get log chunk #{start}-#{theend}"
    path = "#{@url_prefix}/build/#{esc project}/#{esc repo}/#{esc arch}/#{esc package}/_log?nostream=1&start=#{start}&end=#{theend}"
    transport.direct_http URI("https://#{path}"), :timeout => 500
  end

  def get_size_of_log( project, package, repo, arch)
    logger.debug "get log entry"
    path = "#{@url_prefix}/build/#{esc project}/#{esc repo}/#{esc arch}/#{esc package}/_log?view=entry"
    data = transport.direct_http URI("https://#{path}"), :timeout => 500
    if ! data
      return 0
    end
    xml = XML::Parser.string(data).parse.root
    return Integer(xml.find_first('//entry')['size'])
  end

  def gethistory(key, range, cache=1)
    cachekey = key + "-#{range}"
    Rails.cache.delete(cachekey) if !cache
    return Rails.cache.fetch(cachekey, :expires_in => (range.to_i * 3600) / 150) do
      hash = Hash.new
      data = transport.direct_http(URI('/public/status/history?key=%s&hours=%d&samples=400' % [key, range]))
      d = XML::Parser.string(data).parse
      d.root.each_element do |v|
        hash[Integer(v.attributes['time'])] = v.attributes['value'].to_f
      end
      hash.sort {|a,b| a[0] <=> b[0]}
    end
  end

  def transport
    @transport ||= ActiveXML::Config::transport_for( :project )
  end
end
