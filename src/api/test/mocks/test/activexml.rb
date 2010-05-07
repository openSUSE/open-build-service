module ActiveXML

  class Base

    #this kind of find can only find by name or :all
    def self.fake_find( fixture, *args )                          
      logger.debug "mock-find called with args #{args.inspect}."
      yaml = YAML::load(ERB.new( IO.read( "#{RAILS_ROOT}/test/fixtures/#{fixture}.yml") ).result)

      case args.first
      when :all then return self.list_all(yaml)
      else                                         
        name = ''                                  
        if args.first.kind_of? String              
          name = args.first                        
        else                                       
          name = args.first[:name]                 
        end                                        
        yaml = {name => yaml[name]}
        if yaml[name].nil?                         
          raise RuntimeError.new("Mock Object #{name} couldn't be found.")
        end
        opt = args[1]
        return self.yaml_to_axml(yaml, opt)
      end
      return 'ups'

    end

    def self.list_all( yaml, opt = {} )
      objs = Array.new
      yaml.each do |key,value|
        obj = self.from_value(value, opt)
        objs << obj
      end
      xml = REXML::Document.new
      xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
      xml.add_element( REXML::Element.new("directory") )
      xml.root.add_attribute REXML::Attribute.new("count", objs.size().to_s)
      objs.each do |obj|
        element = REXML::Element.new( 'entry' )
        element.add_attribute REXML::Attribute.new('name', obj.name)
        xml.root.add_element(element)
      end
      return ActiveXML::XMLNode.new(xml.to_s)
    end

    def self.yaml_to_axml( yaml, opt = {})
      xml = nil
      objs = Array.new

      yaml.each do |key,value|
        objs << self.from_value(value, opt)
      end

      if objs.empty?
        raise RuntimeError, "ALARM: No object found."
      elsif objs.size > 1 then
        return objs
      else
        return objs[0]
      end
    end
  end

end

