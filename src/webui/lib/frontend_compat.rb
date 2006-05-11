require 'activexml'

class FrontendCompat
  def initialize
  end

  def logger
    ActiveXML::Config.logger
  end

  def cmd_package( project, package, cmd )
    transport.direct_http URI("http:///source/#{project}/#{package}?#{cmd}"), :method => "POST", :data => ""
  end

  def get_source( opt={} )
    logger.debug "--> get_source: #{opt.inspect}"
    path = '/source'
    path += "/#{opt[:project]}" if opt[:project]
    path += "/#{opt[:package]}" if opt[:project] && opt[:package]
    path += "/#{opt[:filename]}" if opt[:filename]
    logger.debug "--> get_source path: #{path}"
    
    transport.direct_http URI("http://#{path}")
  end

  def put_file( data, opt={} )
    transport.direct_http URI("http:///source/#{opt[:project]}/#{opt[:package]}/#{opt[:filename]}"),
      :method => "PUT", :data => data
  end

  def get_log_chunk( project, package, repo, arch, offset=0 )
    path = "/result/#{project}/#{repo}/#{package}/#{arch}/log?nostream=1&start=#{offset}"
    transport.direct_http URI("http://#{path}")
  end

  def transport
    @transport ||= ActiveXML::Config::transport_for( :project )
  end
end
