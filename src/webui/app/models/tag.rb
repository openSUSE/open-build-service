require 'xml'

class Tag < ActiveXML::Base
  
  class << self
    
    # redefine make_stub to achieve taglist needs 
    def make_stub( opt )                  
      
      xml = XML::Document.new
      xml.root = XML::Node.new 'tags'
      xml.root["project"] = opt[:project]
      xml.root["package"] = opt[:package] if opt[:package]
      
      opt[:tag].split(" ").each do |tag|
        tag = tag.strip
        #escaping entities is not enough!
        tag.gsub!("\&","&amp;")
        #ActiveRecord::Base.logger.debug "[TAG:] gsub Tag: #{tag}"
        element = xml.root << 'tag'
        element['name'] = tag
      end
      xml.root
    end
    
  end #self
  
  #TODO: I'll remove it later. 
  #  def update (params)
  #    
  #       #logger.debug "saving #{object.inspect}"
  #        #url = substituted_uri_for( object )
  #        url = URI.parse "http://localhost:3001/user/#{params[:user]}/tags/#{params[:project]}/#{params[:package]}"
  #
  #        self.class.transport.http_do 'put', url, self.dump_xml
  #        return true     
  #      end
  
end #class
