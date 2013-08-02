class ApiDetails

  class CommandFailed < Exception ; end

  def self.logger
    Rails.logger
  end

  # FIXME: legacy
  def self.create_role(project_name, opts)
    opts.delete :todo
    if opts[:package].blank?
      uri = URI("/webui/projects/#{project_name}/relationships")
    else
      uri = URI("/webui/projects/#{project_name}/packages/#{opts[:package]}/relationships")
      opts.delete :package
    end
    uri = self.url_for(uri, opts)
    begin
      ActiveXML::transport.http_json :post, uri
    rescue ActiveXML::Transport::Error => e
      raise CommandFailed, e.summary
    end
  end

  # FIXME: legacy
  def self.remove_role(project_name, opts)
    opts.delete :todo
    if opts[:package].blank?
      uri = URI("/webui/projects/#{project_name}/relationships/remove_user")
    else
      uri = URI("/webui/projects/#{project_name}/packages/#{opts[:package]}/relationships/remove_user")
      opts.delete :package
    end
    uri = self.url_for(uri, opts)
    begin
      ActiveXML::transport.http_json :delete, uri
    rescue ActiveXML::Transport::Error => e
      raise CommandFailed, e.summary
    end
  end

  def self.save_comments(route_name, params)
    uri = "/webui/" +
    case route_name.to_sym
      when :save_comments_for_projects then "comments/project/#{params[:project]}/new"
    end

    uri = URI(uri)
    data = ActiveXML::transport.http_json :post, uri, params
    data
  end

  # Trying to mimic the names and params of Rails' url helpers
  def self.read(route_name, *args)
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
      when :infos_project then "projects/#{ids.first}/infos"
      when :status_project then "projects/#{ids.first}/status"

      when :requests then "requests"
      when :request then "requests/#{ids.first}"
      when :ids_requests then "requests/ids"
      when :by_class_requests then "requests/by_class"
<<<<<<< HEAD
  
=======

      when :comments_by_package then "comments/package/#{ids.first}/#{ids.last}"
      when :comments_by_project then "comments/project/#{ids.first}"
      when :comments_by_request then "comments/request/#{ids.first}"
>>>>>>> [webui][api] refactoring to make the code more object oriented
      else raise "no valid route #{route_name}"
      end
    uri = url_for(uri, opts)
    transport = ActiveXML::transport
    data = transport.http_do 'get', uri
    data = JSON.parse(data)
    logger.debug "data #{JSON.pretty_generate(data)}"
    data
  end

  def self.url_for(uri, opts = {})
    if opts.empty?
      uri
    else
      "#{uri}?#{opts.to_query}"
    end
  end
end

