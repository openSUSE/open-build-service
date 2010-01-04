require 'models/project'

#require File.dirname(__FILE__) + '/../test_helper'



class Project

  #this kind of find can only find by project-name or :all
  def self.find( *args )
    logger.debug "Project mock-find called with args #{args.inspect}."
    #puts "Project mock-find called with args #{args.inspect}."
    yaml = YAML::load(ERB.new( IO.read(File.dirname(__FILE__) + '/../../fixtures/projects.yml') ).result)
   
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
          raise RuntimeError.new("Project #{args.first[:name]} couldn't be found.")
        end            
        return self.yaml_to_axml(yaml)
    end
    
    return 'upps'
  end
  
  
  def self.yaml_to_axml( yaml )
    xml = nil
    projects = Array.new
    
    yaml.each do |key,value|
      projects << Project.new(value)
    end
    
    if projects.empty?
      logger.debug "ALARM: No project found."
      raise
    elsif projects.size > 1 then
      return projects
    else
      return projects[0]
    end
  end
  
  
end