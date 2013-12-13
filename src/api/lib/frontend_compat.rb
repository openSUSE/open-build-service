class FrontendCompat

  include Escaper

  def logger
    Rails.logger
  end

  def source_cmd( cmd, opt={} )
    extraparams = ''
    extraparams << "&repository=#{esc opt[:repository]}" if opt[:repository]
    extraparams << "&arch=#{esc opt[:arch]}" if opt[:arch]
    extraparams << "&flag=#{esc opt[:flag]}" if opt[:flag]
    extraparams << "&status=#{esc opt[:status]}" if opt[:status]

    raise RuntimeError, 'no project given' unless opt[:project]
    logger.debug "SOURCE CMD #{cmd} ; extraparams = #{extraparams}"
    path = "/source/#{pesc opt[:project]}"
    path += "/#{esc opt[:package].to_s}" if opt[:package]
    path += "?cmd=#{cmd}#{extraparams}"
    
    transport.direct_http URI(path), :method => 'POST', :data => ''
  end

  #  opt takes keys: project(needed), repository, arch
  #  missing project raises RuntimeError
  def cmd( command, opt={} )
    raise RuntimeError, 'project name missing' unless opt.has_key? :project
    logger.debug "--> #{command}: #{opt.inspect}"
    path = "/build/#{opt[:project]}?cmd=#{command}"
    opt.delete :project

    valid_opts = 'project package repository arch code'
    opt.each do |key, val|
      raise RuntimeError, "unknown method parameter #{key}" unless valid_opts.include? key.to_s
      path += "&#{key.to_s}=#{esc val}"
    end
    transport.direct_http URI("#{path}"), :method => 'POST', :data => ''
  end

  def put_file( data, opt={} )
    path = '/source'
    path += "/#{pesc opt[:project]}" if opt[:project]
    path += "/#{pesc opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{pesc opt[:filename]}" if opt[:filename]
    path += "?comment=#{esc opt[:comment]}" unless opt[:comment].blank?
    transport.http_do :put, URI("#{path}"), data: data, timeout: 500
  end

  def do_post( data, opt={} )
    path = '/source'
    path += "/#{pesc opt[:project]}" if opt[:project]
    path += "/#{pesc opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{pesc opt[:filename]}" if opt[:filename]
    path += '?'
    path += "cmd=#{esc opt[:cmd]}" unless opt[:cmd].blank?
    path += "&targetproject=#{esc opt[:targetproject]}" unless opt[:targetproject].blank?
    path += "&targetrepository=#{esc opt[:targetrepository]}" unless opt[:targetrepository].blank?
    path += "&comment=#{esc opt[:comment]}" unless opt[:comment].blank?
    transport.http_do :post, URI("#{path}"), data: data, timeout: 500
  end

  def delete_package( opt={} )
    logger.debug "deleting: #{opt.inspect}"
    transport.direct_http URI("/source/#{pesc opt[:project]}/#{pesc opt[:package]}"),
      :method => 'DELETE', :timeout => 500
  end

  def transport
    ActiveXML.api
  end
end
