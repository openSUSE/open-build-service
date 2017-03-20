# Class to read and write the "_services" file on the Backend
class Service < ActiveXML::Node
  class InvalidParameter < APIException; end

  #### Class methods using self. (public and then private)
  def self.make_stub(_opt)
    "<services/>"
  end

  def self.valid_name?(name)
    return false unless name.kind_of?(String)
    return false if name.length > 200 || name.blank?
    return false if name =~ %r{^[_\.]}
    return false if name =~ %r{::}
    return true if name =~ /\A\w[-+\w\.:]*\z/
    false
  end

  def self.verify_xml!(raw_post)
    Xmlhash.parse(raw_post).elements('service').each do |s|
      raise InvalidParameter.new "service name #{s['name']} contains invalid chars" unless valid_name?(s['name'])
      s.elements('param').each do |p|
        raise InvalidParameter.new "service parameter #{p['name']} contains invalid chars" unless valid_name?(p['name'])
      end
    end
  end

  #### Instance methods (public and then protected/private)
  def addDownloadURL(url, filename = nil)
    begin
      uri = URI.parse(url)
    rescue
      return false
    end

    # default for download_url and download_src_package
    service_content = [
      {name: "host", value: uri.host},
      {name: "protocol", value: uri.scheme},
      {name: "path", value: uri.path}
    ]
    unless (uri.scheme == "http" && uri.port == 80) ||
           (uri.scheme == "https" && uri.port == 443) ||
           (uri.scheme == "ftp" && uri.port == 21)
      service_content << {name: "port", value: uri.port} # be nice and skip it for simpler _service file
    end

    if uri.path =~ /.src.rpm$/ || uri.path =~ /.spm$/ # download and extract source package
      addService("download_src_package", service_content)
    elsif uri.scheme == "git"
      service_content = [{name: "scm", value: "git"}, {name: "url", value: url}]
      addService("obs_scm", service_content)
      addService("tar", nil, "buildtime")
      service_content = [{name: "compression", value: "xz"}, {name: "file", value: "*.tar"}]
      addService("recompress", service_content, "buildtime")
      addService("set_version", nil, "buildtime")
    else # just download
      service_content << {name: "filename", value: filename} unless filename.blank?
      addService("download_url", service_content)
    end
    true
  end

  def addKiwiImport
    addService('kiwi_import')
    if save
      logger.debug 'Service successfully saved'
      begin
        logger.debug 'Executing waitservice command'
        Suse::Backend.post("/source/#{URI.escape(init_options[:project])}/#{URI.escape(init_options[:package])}?cmd=waitservice")
        logger.debug 'Executing mergeservice command'
        cmd = "/source/#{URI.escape(init_options[:project])}/#{URI.escape(init_options[:package])}?cmd=mergeservice&user=#{User.current.login}"
        Suse::Backend.post(cmd)
      rescue ActiveXML::Transport::Error, Timeout::Error => e
        logger.debug "Error while executing backend command: #{e.message}"
      end
    else
      logger.debug 'Failed to save service'
    end
  end

  def fill_params(element, parameters)
    parameters.each { |parameter|
      param = element.add_element('param', name: parameter[:name])
      param.text = parameter[:value]
    }
    true
  end

  # parameters need to be given as an array with hash pairs :name and :value
  def addService(name, parameters = [], mode = nil)
    attribs = { name: name }
    attribs[:mode] =  mode if mode
    element = add_element('service', attribs)
    fill_params(element, parameters)
  end

  def save
    if !has_element?('/services/service')
      begin
        delete
      rescue ActiveXML::Transport::NotFoundError
        # to be ignored, if it's gone, it's gone
      end
    else
      super(comment: 'Modified via webui', user: User.current.login)
      package = Package.get_by_project_and_name(init_options[:project], init_options[:package],
                                                use_source: true, follow_project_links: false)
      return false unless User.current.can_modify_package?(package)
      Suse::Backend.post("/source/#{init_options[:project]}/#{init_options[:package]}?cmd=runservice&user=#{User.current.login}")
      package.sources_changed
    end
    true
  end
end
