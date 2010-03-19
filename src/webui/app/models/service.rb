class Service < ActiveXML::Base

  class << self
    def make_stub( opt )
      logger.debug "make stub params: #{opt.inspect}"
      doc = XML::Document.new
      doc.root = XML::Node.new 'services'
      doc.root
    end
  end

  def add_download url
    e = add_element "service", 'name' => "download_url"
    s = e.add_element "param", 'name' => "protocol"
    s.text = "http"
    s = e.add_element "param", 'name' => "host"
    s.text = "bah.org"
    s = e.add_element "param", 'name' => "path"
    s.text = "asd/asd.gz"
  end

end
