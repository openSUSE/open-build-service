class WebuiGroup < WebuiNode
  default_find_parameter :title
  handles_xml_element :group

  class << self
    def make_stub(opt)
      name = ''
      name = opt[:name] if opt.has_key? :name
      members = []
      members = opt[:members].split(',') if opt.has_key? :members

      reply = "<group><title>#{opt[:name]}</title>"
      if members.length > 0
        reply << '<person>'
        members.each do |person|
          reply << "<person userid=\"#{person}\"/>"
        end
        reply << '</person>'
      end
      reply << '</group>'
      return reply
    end
  end

end
