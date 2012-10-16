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
    transport = ActiveXML::transport
    uri = transport.substitute_uri(uri, opts)
    transport.replace_server_if_needed(uri)
    data = transport.direct_http(uri)
    ActiveSupport::JSON.decode(data)
  end
end

