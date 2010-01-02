module ActiveXML

  class Base

    #this kind of find can only find by name or :all
    def self.fake_find( fixture, *args )                          
      logger.debug "mock-find called with args #{args.inspect}."
      yaml = YAML::load(ERB.new( IO.read( "#{RAILS_ROOT}/test/fixtures/#{fixture}.yml") ).result)

      case args.first
      when :all then return self.yaml_to_axml(yaml)
      else                                         
        name = ''                                  
        if args.first.kind_of? String              
          name = args.first                        
        else                                       
          name = args.first[:name]                 
        end                                        
        yaml = {name => yaml[name]}                
        if yaml[name].nil?                         
          raise RuntimeError.new("Mock Object #{args.first[:name]} couldn't be found.")
        end
        return self.yaml_to_axml(yaml)
      end
      return 'ups'

    end

    def self.yaml_to_axml( yaml )
      xml = nil
      objs = Array.new

      yaml.each do |key,value|
        objs << self.from_value(value)
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

