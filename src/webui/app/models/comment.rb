class Comment < ActiveXML::Node
  handles_xml_element 'comment'

  class << self
    def make_stub( opt )

      if opt[:package]
        xml_structure = "<comments object_type=\"#{opt[:object_type]}\" project=\"#{opt[:project_with_package]}\" package=\"#{opt[:package]}\">"
      elsif opt[:request_id]
        xml_structure = "<comments object_type=\"#{opt[:object_type]}\" request_id=\"#{opt[:request_id]}\">"
      else
        xml_structure = "<comments object_type=\"#{opt[:object_type]}\" project=\"#{opt[:project]}\">"
      end

      if opt[:parent_id]
        xml_structure += "<list user=\"#{opt[:user]}\" title=\"#{opt[:title]}\" parent_id=\"#{opt[:parent_id]}\">"
      else
        xml_structure += "<list user=\"#{opt[:user]}\" title=\"#{opt[:title]}\">"
      end
      
      xml_structure += "#{opt[:body]}"
      xml_structure += "</list>"
      xml_structure +="</comments>"
    end
  end

    # Since comment is being posted to request, project and package, save method is being manually written.
  def save
    package = self.init_options[:package]
    request = self.init_options[:request_id]
    if package
      path = "/comments/package/#{self.init_options[:project_with_package]}/#{self.init_options[:package]}"
    elsif request
      path = "/comments/request/#{self.init_options[:request_id]}"
    else
      path = "/comments/project/#{self.init_options[:project]}"
    end
    frontend = ActiveXML::transport 
    frontend.direct_http URI("#{path}"), :method => "POST", :data => self.dump_xml
  end

  def self.find_by_package(args = {})
    path = "/comments/package/#{args[:project]}/#{args[:package]}"
    path = URI(path)
    transport = ActiveXML::transport
    data = transport.http_do 'get', path
    data
  end

  def self.find_by_request_id(args = {})
    path = "/comments/request/#{args[:id]}"
    path = URI(path)
    transport = ActiveXML::transport
    data = transport.http_do 'get', path
    data
  end
end
