class ApiDetails

  def self.logger
    Rails.logger
  end

  def self.find(info, opts)
    uri = "/webui/"
    uri += 
      case info 
      when :project_infos then "project_infos?project=:project"
      when :project_requests then "project_requests?project=:project"
      else raise "no valid info #{info}"
      end
    uri = URI(uri)
    uri.scheme, uri.host, uri.port = ActiveXML::Config::TransportMap.get_default_server :rest
    uri = ActiveXML::Transport::Rest.substitute_uri(uri, opts)
    data = ActiveXML::Config::transport_for(:package).direct_http(uri)
    ActiveSupport::JSON.decode(data)
  end
end

