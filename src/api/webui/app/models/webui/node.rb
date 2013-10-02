class Webui::Node < ActiveXML::Node
  def self.transport
    ActiveXML::api
  end
end

