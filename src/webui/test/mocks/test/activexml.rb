
require "rexml/document"

module ActiveXML

  class Base

    def self.load_fixture(fixture, *args)
      logger.debug "mock load fix called with args #{args.inspect}."
      yaml = YAML::load(ERB.new( IO.read( "#{RAILS_ROOT}/test/fixtures/#{fixture}.yml") ).result) 
      name = ''                                  
      if args.first.kind_of? String              
        name = args.first                        
      else                                       
        name = args.first[0]
      end                                        
      yaml = {name => yaml[name]}
      if yaml[name].nil?                         
        raise RuntimeError.new("Mock Object #{name} couldn't be found.")
      end
      opt = args[1]
      return self.yaml_to_axml(yaml, opt)
    end
 
    def self.find_priv(cache_time, *args )
      logger.debug "mock-find called with args #{args.inspect} on #{self.name}"
      fixture = self.name.downcase.pluralize
      if args.first == :all
        yaml = YAML::load(ERB.new( IO.read( "#{RAILS_ROOT}/test/fixtures/#{fixture}.yml") ).result)
        return self.list_all(yaml)
      end
      fixture = self.name.downcase.pluralize
      unless File.exists? "#{RAILS_ROOT}/test/fixtures/#{fixture}.yml"
        logger.debug "no such file: '#{RAILS_ROOT}/test/fixtures/#{fixture}.yml'"
        return nil
      end
      return load_fixture(fixture, args)   
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

