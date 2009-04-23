require 'models/package'

class Package
  #this kind of find can only find by project-name or :all
  def self.find( *args )
    logger.debug "Package mock-find called with args #{args.inspect}."
    #puts "Package mock-find called with args #{args.inspect}."    
    yaml = YAML::load(ERB.new( IO.read(File.dirname(__FILE__) + '/../../fixtures/packages.yml') ).result)
   
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
          raise RuntimeError.new("Package #{args.first[:name]} couldn't be found.")
        end        
        
        return self.yaml_to_axml(yaml)
    end
    
    return 'upps'
  end
  
  
  def self.yaml_to_axml( yaml )
    xml = nil
    packages = Array.new
    
    yaml.each do |key,value|
      packages << Package.new(value)
    end
    
    if packages.size > 1 then
      return packages
    else
      return packages[0]
    end
  end      
  
  
end