class Service < ActiveXML::Base

  belongs_to :package

  class << self
    def make_stub( opt )
      logger.debug "make stub params: #{opt.inspect}"
      doc = XML::Document.new
      doc.root = XML::Node.new 'services'
    end

    def available
      # hardcoded for now, this should get checked via installed services
      [
             { "icon" => "download",  "name" => "download_url",    "summary" => "Download File" },
             { "icon" => "download",  "name" => "download_src_package",    "summary" => "Download src rpm and extract" },
             { "icon" => "verify",    "name" => "verify_file",     "summary" => "Verify a file" },
             { "icon" => "generator", "name" => "generator_qmake", "summary" => "Generator for qmake" },
             { "icon" => "generator", "name" => "generator_kde",   "summary" => "Generator for KDE" },
      ]
    end
  end

  def addDownloadURL( url )
     uri = URI.parse( url )

     param = {}
     param[:host] = uri.host
     param[:protocol] = uri.scheme
     param[:path] = uri.path
     unless ( uri.scheme == "http" and uri.port == 80 ) or ( uri.scheme == "https" and uri.port == 443 ) or ( uri.scheme == "ftp" and uri.port == 21 )
        # be nice and skip it for simpler file
        param[:port] = uri.port
     end

     if uri.path =~ /.src.rpm$/ or uri.path =~ /.spm$/
        # download and extract source package
        addService( "download_src_package", param )
     else
        # just download
        addService( "download_url", param )
     end
  end

  def removeService( serviceid )
     service_elements = data.find("/services/service")
     return false if service_elements.count < serviceid.to_i or service_elements.count <= 0

     service_elements[serviceid.to_i-1].remove!
     return true
  end

  def addService( name, position=-1, opts={} )
     if position < 0 # append it
        add_element 'service', 'name' => name
        element = data.find("/services/service").last
     else
        service_elements = data.find("/services/service")
        return false if service_elements.count < position or service_elements.count <= 0
        service_elements[position-1].prev = XML::Node.new 'service'
        element = service_elements[position-1].prev
        element['name'] = name.to_s
     end
     opts.each_pair{ |key, value|
       param = XML::Node.new 'param'
       param['name'] = key.to_s
       param << value.to_s
       element << param
     }
     return true
  end

  def moveService( from, to )
     service_elements = data.find("/services/service")
     return false if service_elements.count < from or service_elements.count < to or service_elements.count <= 0
     service_elements[to-1].prev = service_elements[from-1]
#     service_elements[from-1].remove!
  end

  def execute()
    opt = Hash.new
    opt[:project] = self.init_options[:project]
    opt[:package] = self.init_options[:package]
    opt[:cmd] = "runservice"
    logger.debug "execute services"
    fc = FrontendCompat.new
    fc.do_post nil, opt
  end

  def save
    opt = Hash.new
    opt[:project] = self.init_options[:project]
    opt[:package] = self.init_options[:package]
    opt[:filename] = "_service"
    opt[:comment] = "Modified via webui"

    fc = FrontendCompat.new
    if data.find("/services/service").count > 0
      logger.debug "storing _service file"
      fc.put_file self.data.to_s, opt
      opt.delete :filename
      opt[:cmd] = "runservice"
      fc.do_post nil, opt
    else
      logger.debug "remove _service file"
      fc.delete_file opt
    end
    true
  end

end
