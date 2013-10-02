class Webui::ApiDetails

  class TransportError < Exception ; end
  class NotFoundError < Exception ; end

  def self.logger
    Rails.logger
  end

  def self.prepare_search
    transport = ActiveXML::api
    transport.http_do 'post', "/test/prepare_search"
  end

  def self.read(route_name, *args)
    http_do :get, route_name, *args
  end

  def self.create(route_name, *args)
    http_do :post, route_name, *args
  end

  def self.destroy(route_name, *args)
    http_do :delete, route_name, *args
  end

  def self.save_comment(route_name, params)
    uri = "/webui/" +
    case route_name.to_sym
      when :save_project_comment then "comments/project/#{params[:project]}/new"
      when :save_package_comment then "comments/package/#{params[:project]}/#{params[:package]}/new"
      when :save_request_comment then "comments/request/#{params[:id]}/new"
      when :delete_project_comment then "comments/project/#{params[:project]}/delete"
      when :delete_package_comment then "comments/package/#{params[:project]}/#{params[:package]}/delete"
      when :delete_request_comment then "comments/request/#{params[:id]}/delete"
    end

    uri = URI(uri)
    data = ActiveXML::api.http_json :post, uri, params
    data
  end

  # Trying to mimic the names and params of Rails' url helpers
  def self.http_do(verb, route_name, *args)
    # FIXME: we need a better (real) implementation of nested routes
    # using rails facilities
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

      when :projects then "projects"
      when :projects_remotes then "projects/remotes"
      when :infos_project then "projects/#{ids.first}/infos"
      when :status_project then "projects/#{ids.first}/status"
      when :project_relationships then "projects/#{ids.first}/relationships"
      when :project_package_relationships then "projects/#{ids.first}/packages/#{ids.last}/relationships"
      when :for_user_project_relationships then "projects/#{ids.first}/relationships/for_user"
      when :for_user_project_package_relationships then "projects/#{ids.first}/packages/#{ids.last}/relationships/for_user"

      when :package_rdiff then "projects/#{ids.first}/packages/#{ids.last}/rdiff"

      when :requests then "requests"
      when :request then "requests/#{ids.first}"
      when :ids_requests then "requests/ids"
      when :by_class_requests then "requests/by_class"

      when :attrib_types then "attrib_types"

      when :searches then "searches"

      when :comments_by_package then "comments/package/#{ids.first}/#{ids.last}"
      when :comments_by_project then "comments/project/#{ids.first}"
      when :comments_by_request then "comments/request/#{ids.first}"

      else raise "no valid route #{route_name}"
      end

    transport = ActiveXML::api
    begin
      if [:get, :delete].include? verb.to_sym
        uri = "#{uri}?#{opts.to_query}" unless opts.empty?
        data = transport.http_do verb, uri
      else
        data = transport.http_json verb, URI(uri), opts
      end
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

