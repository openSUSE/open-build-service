class Service < ActiveXML::Base

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
             { "icon" => "verify",    "name" => "verify_file",     "summary" => "Verify a file" },
             { "icon" => "generator", "name" => "generator_qmake", "summary" => "Generator for qmake" },
             { "icon" => "generator", "name" => "generator_kde",   "summary" => "Generator for KDE" },
      ]
    end
  end

end
