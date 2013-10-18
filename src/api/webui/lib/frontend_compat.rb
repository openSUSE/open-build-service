class FrontendCompat

  # parameters escape
  def esc(str)
    CGI.escape str.to_s
  end

  # path escape
  def pesc(str)
    URI.escape str.to_s
  end

  def initialize
    @url_prefix = CONFIG['api_relative_url_root'] || ""
  end

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
    path = "#{@url_prefix}/source/#{pesc opt[:project]}"
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
    transport.direct_http URI("#{path}"), :method => "POST", :data => ""
  end

  def get_source( opt={} )
    logger.debug "--> get_source: #{opt.inspect}"
    path = "#{@url_prefix}/source"
    path += "/#{pesc opt[:project]}" if opt[:project]
    path += "/#{pesc opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{pesc opt[:filename]}" if opt[:filename]
    extra = []
    extra << "rev=#{esc opt[:rev]}" if opt[:rev]
    extra << "expand=#{opt[:expand]}" if opt[:expand]
    path += "?#{extra.join('&')}" if extra.length
    logger.debug "--> get_source path: #{path}"
    
    transport.http_do :get, URI("#{path}")
  end

  def put_file( data, opt={} )
    path = "#{@url_prefix}/source"
    path += "/#{pesc opt[:project]}" if opt[:project]
    path += "/#{pesc opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{pesc opt[:filename]}" if opt[:filename]
    path += "?comment=#{esc opt[:comment]}" unless opt[:comment].blank?
    transport.http_do :put, URI("#{path}"), data: data, timeout: 500
  end

  def do_post( data, opt={} )
    path = "#{@url_prefix}/source"
    path += "/#{pesc opt[:project]}" if opt[:project]
    path += "/#{pesc opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{pesc opt[:filename]}" if opt[:filename]
    path += "?"
    path += "cmd=#{esc opt[:cmd]}" unless opt[:cmd].blank?
    path += "&targetproject=#{esc opt[:targetproject]}" unless opt[:targetproject].blank?
    path += "&targetrepository=#{esc opt[:targetrepository]}" unless opt[:targetrepository].blank?
    path += "&comment=#{esc opt[:comment]}" unless opt[:comment].blank?
    transport.http_do :post, URI("#{path}"), data: data, timeout: 500
  end

  def delete_package( opt={} )
    logger.debug "deleting: #{opt.inspect}"
    transport.direct_http URI("#{@url_prefix}/source/#{pesc opt[:project]}/#{pesc opt[:package]}"), 
      :method => "DELETE", :timeout => 500
  end

  def delete_file( opt={} )
    logger.debug "starting to delete file, opt: #{opt.inspect}"
    transport.direct_http URI("#{@url_prefix}/source/#{pesc opt[:project]}/#{pesc opt[:package]}/#{pesc opt[:filename]}"),
      :method => "DELETE", :timeout => 500
  end

  def get_log_chunk( project, package, repo, arch, start, theend )
    logger.debug "get log chunk #{start}-#{theend}"
    path = "#{@url_prefix}/build/#{pesc project}/#{pesc repo}/#{pesc arch}/#{pesc package}/_log?nostream=1&start=#{start}&end=#{theend}"
    log = transport.direct_http URI("#{path}"), :timeout => 500
    begin
      log.encode!(invalid: :replace, xml: :text, undef: :replace, cr_newline: true)
    rescue Encoding::UndefinedConversionError
       # encode is documented not to throw it if undef: is :replace, but at least we tried - and ruby 1.9.3 is buggy
    end
    return log.gsub(/([^a-zA-Z0-9&;<>\/\n\r \t()])/) do |c|
      begin
        if c.ord < 32
          ''
        else
          c
        end
      rescue ArgumentError
        ''
      end
    end
  end

  def get_size_of_log( project, package, repo, arch)
    logger.debug "get log entry"
    path = "#{@url_prefix}/build/#{pesc project}/#{pesc repo}/#{pesc arch}/#{pesc package}/_log?view=entry"
    data = transport.direct_http URI("#{path}"), :timeout => 500
    return 0 unless data
    doc = Nokogiri::XML(data)
    return doc.root.first_element_child().attributes['size'].value.to_i
  end

  def gethistory(key, range, cache=1)
    cachekey = key + "-#{range}"
    Rails.cache.delete(cachekey, :shared => true) if !cache
    return Rails.cache.fetch(cachekey, :expires_in => (range.to_i * 3600) / 150, :shared => true) do
      hash = Hash.new
      data = transport.direct_http(URI('/status/history?key=%s&hours=%d&samples=400' % [key, range]))
      doc = Nokogiri::XML(data)
      doc.root.elements.each do |value|
        hash[value.attributes['time'].value.to_i] = value.attributes['value'].value.to_f
      end
      hash.sort {|a,b| a[0] <=> b[0]}
    end
  end

  def get_rpmlint_log(project, package, repository, architecture)
    logger.debug "get rpmlint log"
    path = "#{@url_prefix}/build/#{pesc project}/#{pesc repository}/#{pesc architecture}/#{pesc package}/rpmlint.log"
    data = transport.direct_http(URI(path), :timeout => 500)
    return data
  end

  def transport
    ActiveXML.api
  end
end
