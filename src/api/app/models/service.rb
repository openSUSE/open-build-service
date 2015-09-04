class Service < ActiveXML::Node

  def self.make_stub(_opt)
    "<services/>"
  end

  class InvalidParameter < APIException
  end

  def addDownloadURL(url, filename=nil)
    begin
      uri = URI.parse(url)
    rescue
      return false
    end

    # default for download_url and download_src_package
    p = []
    p << {:name => "host", :value => uri.host}
    p << {:name => "protocol", :value => uri.scheme}
    p << {:name => "path", :value => uri.path}
    unless (uri.scheme == "http" and uri.port == 80) or (uri.scheme == "https" and uri.port == 443) or (uri.scheme == "ftp" and uri.port == 21)
      # be nice and skip it for simpler _service file
      p << {:name => "port", :value => uri.port}
    end

    if uri.path =~ /.src.rpm$/ or uri.path =~ /.spm$/
      # download and extract source package
      addService("download_src_package", -1, p)
    elsif uri.scheme == "git"
      p = []
      p << {:name => "scm", :value => "git"}
      p << {:name => "url", :value => url}
      addService("tar_scm", -1, p)
      p = []
      p << {:name => "compression", :value => "xz"}
      p << {:name => "file", :value => "*.tar"}
      addService("recompress", -1, p)
      addService("set_version")
    else
      # just download
      p << {:name => "filename", :value => filename} unless filename.blank?
      addService("download_url", -1, p)
    end
    return true
  end

  def removeService(serviceid)
    each("/services/service") do |service|
      serviceid=serviceid-1
      if serviceid == 0
        delete_element service
        return true
      end
    end
    return false
  end

  def fill_params(element, parameters)
    parameters.each { |p|
      param = element.add_element('param', :name => p[:name])
      param.text = p[:value]
    }
    true
  end

  # parameters need to be given as an array with hash pairs :name and :value
  def addService(name, position=-1, parameters=[])
    element = add_element 'service', 'name' => name
    if position >= 0
      service_elements = each("/services/service")
      if service_elements.count >= position
        element.move_before(service_elements[position-1])
      end
    end
    fill_params(element, parameters)
  end

  def error
    opt = Hash.new
    opt[:project] = self.init_options[:project]
    opt[:package] = self.init_options[:package]
    opt[:expand] = self.init_options[:expand]
    opt[:rev] = self.init_options[:revision]
    begin
      fc = FrontendCompat.new
      answer = fc.get_source opt
      doc = ActiveXML::Node.new(answer)
      doc.each('/directory/serviceinfo/error') do |e|
        return e.text
      end
    rescue
      return nil
    end
  end

  def execute
    opt = Hash.new
    opt[:project] = self.init_options[:project]
    opt[:package] = self.init_options[:package]
    opt[:expand] = self.init_options[:expand]
    opt[:cmd] = 'runservice'
    logger.debug 'execute services'
    fc = FrontendCompat.new
    fc.do_post nil, opt
  end

  def self.valid_name?(name)
    return false unless name.kind_of? String
    return false if name.length > 200 || name.blank?
    return false if name =~ %r{^[_\.]}
    return false if name =~ %r{::}
    return true if name =~ /\A\w[-+\w\.:]*\z/
    false
  end

  def self.verify_xml!(raw_post)
    data = Xmlhash.parse(raw_post)
    data.elements('service').each do |s|
      raise InvalidParameter.new "service name #{s['name']} contains invalid chars" unless valid_name?(s['name'])
      s.elements('param').each do |p|
        raise InvalidParameter.new "service parameter #{p['name']} contains invalid chars" unless valid_name?(p['name'])
      end
    end
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
      fc = FrontendCompat.new
      fc.do_post nil, self.init_options.merge(:cmd => 'runservice')
    end
    true
  end

end
