# Class to read and write the "_services" file on the Backend
class Service
  include ActiveModel::Model
  include Package::Errors
  class InvalidParameter < APIError; end

  attr_accessor :package

  # helper function
  delegate :project, to: :package

  def document
    return @document if @document

    xml = Backend::Api::Sources::Package.service(project.name, package.name)
    xml ||= '<services/>'
    @document = Nokogiri::XML(xml, &:strict)
  end

  def self.verify_xml!(raw_post)
    Xmlhash.parse(raw_post).elements('service').each do |s|
      raise InvalidParameter, "service name #{s['name']} contains invalid chars" unless Service::NameValidator.new(s['name']).valid?

      s.elements('param').each do |p|
        raise InvalidParameter, "service parameter #{p['name']} contains invalid chars" unless Service::NameValidator.new(p['name']).valid?
      end
    end
  end

  #### Instance methods (public and then protected/private)
  def add_download_url(url, filename = nil)
    if url.starts_with?('git@') || url.ends_with?('.git')
      add_scm_service(url)
      return true
    end

    begin
      uri = URI.parse(url)
    rescue StandardError
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
      add_service('download_src_package', service_content)
    else # just download
      service_content << { name: 'filename', value: filename } if filename.present?
      add_service('download_url', service_content)
    end
    true
  end

  def add_kiwi_import
    add_service('kiwi_import')
    return unless save

    begin
      Backend::Api::Sources::Package.wait_service(project.name, package.name)
      Backend::Api::Sources::Package.merge_service(project.name, package.name, User.session!.login)
    rescue Backend::Error, Timeout::Error => e
      Rails.logger.debug { "Error while executing backend command: #{e.message}" }
    end
  end

  # parameters need to be given as an array with hash pairs :name and :value
  def add_service(name, parameters = [], mode = nil)
    attribs = { name: name }
    attribs[:mode] =  mode if mode
    element = document.create_element('service', attribs)
    fill_params(element, parameters)
    document.root.add_child(element)
  end

  def save
    raise ScmsyncReadOnly if package.scmsync.present?

    if document.xpath('//services/service').empty?
      begin
        Backend::Api::Sources::Package.delete_file(project.name, package.name, '_service')
      rescue Backend::NotFoundError
        # to be ignored, if it's gone, it's gone
      end
    else
      Backend::Api::Sources::Package.write_file(project.name, package.name, '_service', document.root.to_xml,
                                                comment: 'Modified via webui', user: User.session!.login)
      service_package = Package.get_by_project_and_name(project.name, package.name,
                                                        use_source: true, follow_project_links: false)
      return false unless User.session!.can_modify?(service_package)

      Backend::Api::Sources::Package.trigger_services(service_package.project.name, service_package.name, User.session!.login)
      service_package.sources_changed
    end
    true
  end

  private

  def fill_params(element, parameters)
    parameters.each do |parameter|
      param = document.create_element('param', parameter[:value], name: parameter[:name])
      element.add_child(param)
    end
    true
  end

  def add_scm_service(url)
    add_service('obs_scm', [{ name: 'scm', value: 'git' }, { name: 'url', value: url }])
    add_service('tar', [], 'buildtime')
    add_service('recompress', [{ name: 'compression', value: 'xz' }, { name: 'file', value: '*.tar' }], 'buildtime')
    add_service('set_version', [], 'buildtime')

    true
  end
end
