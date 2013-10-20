class Webui::ApiDetails

  class TransportError < Exception ; end
  class NotFoundError < Exception ; end

  def self.logger
    Rails.logger
  end

  def self.read(route_name, *args)
    http_do :get, route_name, *args
  end

  # Trying to mimic the names and params of Rails' url helpers
  def self.http_do(verb, route_name, *args)
    ids = []
    opts = {}
    args.each do |i|
      if i.kind_of? Fixnum
        ids << i.to_s
      elsif i.kind_of? String
        ids << i
      elsif i.kind_of? Hash
        opts = i
      elsif i.respond_to?(:id)
        ids << i.id.to_s
      else
        ids << i.to_s
      end
    end

    uri = "/webui/" +
      case route_name.to_sym

      when :requests then "requests"
      when :request then "requests/#{ids.first}"
      when :ids_requests then "requests/ids"
      when :by_class_requests then "requests/by_class"

      else raise "no valid route #{route_name}"
      end

    transport = ActiveXML::api
    begin
      uri = "#{uri}?#{opts.to_query}" unless opts.empty?
      data = transport.http_do verb, uri
    rescue ActiveXML::Transport::NotFoundError => e
      raise NotFoundError, e.summary
    rescue ActiveXML::Transport::Error => e
      raise TransportError, e.summary
    end
    data = JSON.parse(data)
    logger.debug "data #{JSON.pretty_generate(data)}"
    data
  end

end

