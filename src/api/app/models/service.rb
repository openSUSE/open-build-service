# Class to read and write the "_services" file on the Backend
class Service
  include ActiveModel::Model
  class InvalidParameter < APIError; end

  attr_accessor :package

  # helper function
  delegate :project, to: :package

  def document
    return @document if @document
    xml = Backend::Api::Sources::Package.service(project.name, package.name)
    xml ||= '<services/>'
    @document = Nokogiri::XML(xml)
  end

  def self.valid_name?(name)
    return false unless name.is_a?(String)
    return false if name.length > 200 || name.blank?
    return false if name =~ %r{^[_\.]}
    return false if name =~ %r{::}
    return true if name =~ /\A\w[-+\w\.:]*\z/
    false
  end

  def self.verify_xml!(raw_post)
    Xmlhash.parse(raw_post).elements('service').each do |s|
      raise InvalidParameter, "service name #{s['name']} contains invalid chars" unless valid_name?(s['name'])
      s.elements('param').each do |p|
        raise InvalidParameter, "service parameter #{p['name']} contains invalid chars" unless valid_name?(p['name'])
      end
    end
  end

  #### Instance methods (public and then protected/private)
  def addDownloadURL(url, filename = nil)
    if url.starts_with?('git@') || url.ends_with?('.git')
      add_scm_service(url)
      return true
    end

    begin
      uri = URI.parse(url)
    rescue
      return false
    end

    # default for download_url and download_src_package
    service_content = [
      { name: 'host', value: uri.host },
      { name: 'protocol', value: uri.scheme },
      { name: 'path', value: uri.path }
    ]
    unless (uri.scheme == 'http' && uri.port == 80) ||
           (uri.scheme == 'https' && uri.port == 443) ||
           (uri.scheme == 'ftp' && uri.port == 21)
      service_content << { name: 'port', value: uri.port } # be nice and skip it for simpler _service file
    end

    if uri.path =~ /.src.rpm$/ || uri.path =~ /.spm$/ # download and extract source package
      addService('download_src_package', service_content)
    else # just download
      service_content << { name: 'filename', value: filename } if filename.present?
      addService('download_url', service_content)
    end
    true
  end

  def addKiwiImport
    addService('kiwi_import')
    if save
      Rails.logger.debug 'Service successfully saved'
      begin
        Rails.logger.debug 'Executing waitservice command'
        Backend::Api::Sources::Package.wait_service(project.name, package.name)
        Rails.logger.debug 'Executing mergeservice command'
        Backend::Api::Sources::Package.merge_service(project.name, package.name, User.current.login)
      rescue ActiveXML::Transport::Error, Timeout::Error => e
        Rails.logger.debug "Error while executing backend command: #{e.message}"
      end
    else
      Rails.logger.debug 'Failed to save service'
    end
  end

  def fill_params(element, parameters)
    parameters.each do |parameter|
      param = document.create_element('param', parameter[:value], name: parameter[:name])
      element.add_child(param)
    end
    true
  end

  # parameters need to be given as an array with hash pairs :name and :value
  def addService(name, parameters = [], mode = nil)
    attribs = { name: name }
    attribs[:mode] =  mode if mode
    element = document.create_element('service', attribs)
    fill_params(element, parameters)
    document.root.add_child(element)
  end

  def save
    if document.xpath('//services/service').empty?
      begin
        Backend::Api::Sources::Package.delete_file(project.name, package.name, '_service')
      rescue ActiveXML::Transport::NotFoundError
        # to be ignored, if it's gone, it's gone
      end
    else
      Backend::Api::Sources::Package.write_file(project.name, package.name, '_service', document.root.to_xml,
                                                comment: 'Modified via webui', user: User.current.login)
      service_package = Package.get_by_project_and_name(project.name, package.name,
                                                        use_source: true, follow_project_links: false)
      return false unless User.current.can_modify?(service_package)
      Backend::Api::Sources::Package.run_service(service_package.project.name, service_package.name, User.current.login)
      service_package.sources_changed
    end
    true
  end

  private

  def add_scm_service(url)
    addService('obs_scm', [{ name: 'scm', value: 'git' }, { name: 'url', value: url }])
    addService('tar', [], 'buildtime')
    addService('recompress', [{ name: 'compression', value: 'xz' }, { name: 'file', value: '*.tar' }], 'buildtime')
    addService('set_version', [], 'buildtime')

    return true
  end
end
