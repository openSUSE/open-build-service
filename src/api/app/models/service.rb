# Class to access and/or write the "_services" file on the Backend
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
      {:name => "host", :value => uri.host},
      {:name => "protocol", :value => uri.scheme},
      {:name => "path", :value => uri.path}
      ]
    unless (uri.scheme == "http" && uri.port == 80) ||
           (uri.scheme == "https" && uri.port == 443) ||
           (uri.scheme == "ftp" && uri.port == 21)
      service_content << {:name => "port", :value => uri.port} # be nice and skip it for simpler _service file
    end

    if uri.path =~ /.src.rpm$/ || uri.path =~ /.spm$/ # download and extract source package
      addService("download_src_package", -1, service_content)
    elsif uri.scheme == "git"
      service_content = [{:name => "scm", :value => "git"}, {:name => "url", :value => url}]
      addService("tar_scm", -1, service_content)
      service_content = [{:name => "compression", :value => "xz"}, {:name => "file", :value => "*.tar"}]
      addService("recompress", -1, service_content)
      addService("set_version")
    else # just download
      service_content << {:name => "filename", :value => filename} unless filename.blank?
      addService("download_url", -1, service_content)
    end
    true
  end

  def removeService(serviceid)
    each("/services/service") do |service|
      serviceid -= 1
      if serviceid == 0
        delete_element service
        return true
      end
    end
    false
  end

  def fill_params(element, parameters)
    parameters.each { |parameter|
      param = element.add_element('param', :name => parameter[:name])
      param.text = parameter[:value]
    }
    true
  end

  # parameters need to be given as an array with hash pairs :name and :value
  def addService(name, position = -1, parameters = [])
    element = add_element('service', 'name' => name)
    if position >= 0
      service_elements = each("/services/service")
      element.move_before(service_elements[position-1]) if service_elements.count >= position
    end
    fill_params(element, parameters)
  end

  def error
    opt = {
      project: self.init_options[:project],
      package: self.init_options[:package],
      expand: self.init_options[:expand],
      rev: self.init_options[:revision]
    }
    begin
      fc = FrontendCompat.new
      answer = fc.get_source opt
      doc = ActiveXML::Node.new(answer)
      doc.each('/directory/serviceinfo/error') do |e|
        return e.text
      end
    rescue
      nil
    end
  end

  def execute
    opt = {
      project: self.init_options[:project],
      package: self.init_options[:package],
      expand: self.init_options[:expand],
      cmd: 'runservice'
    }
    logger.debug 'execute services'
    fc = FrontendCompat.new
    fc.do_post nil, opt
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
