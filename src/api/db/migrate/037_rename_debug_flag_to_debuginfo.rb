require "common/opensuse/frontend"
include Suse

class RenameDebugFlagToDebuginfo < ActiveRecord::Migration
  def self.up
    @frontend = Suse::Frontend.new("http://#{SOURCE_HOST}:#{SOURCE_PORT}")
    
    puts "\n[MIGRATION PROJECT-FLAGUPDATE] starting flag update for projects\n" 
    ActiveRecord::Base.logger.debug "\n[MIGRATION FLAGUPDATE] starting flag update for projects\n"
    
    update_project_flags
    
    puts "\n[MIGRATION PROJECT-FLAGUPDATE]...done.\n"
    ActiveRecord::Base.logger.debug "\n[MIGRATION PROJECT-FLAGUPDATE]...done.\n"
    
    puts "\n[MIGRATION PACKAGE-FLAGUPDATE] starting flag update for packages\n"
    ActiveRecord::Base.logger.debug "\n[MIGRATION PACKAGE-FLAGUPDATE] starting flag update for packages\n"
    
    update_package_flags
    
    puts "\n[MIGRATION PACKAGE-FLAGUPDATE] ...done.\n"
    ActiveRecord::Base.logger.debug "\n[MIGRATION PACKAGE-FLAGUPDATE] ...done.\n"
    
    
  end

  
  def self.down
    puts "\n[MIGRATION FLAG-IMPORT] Making a backup of all Flags!\n" 
    ActiveRecord::Base.logger.debug "\n[MIGRATION FLAG-IMPORT] Making a backup of all Flags!\n"
    
    save_table_to_fixture('flags')
    
    puts "\n[MIGRATION FLAG-IMPORT] ...done."
    ActiveRecord::Base.logger.debug "\n[MIGRATION FLAG-IMPORT] ...done."
    
    
    ActiveRecord::Base.logger.debug "\n[MIGRATION FLAG-IMPORT] WARNING: Removing all Flags!\n"     
    save_table_to_fixture('flags')
    
    puts "\n[MIGRATION FLAG-IMPORT] WARNING: Removing all Flags!\n" 
    ActiveRecord::Base.logger.debug "\n[MIGRATION FLAG-IMPORT] WARNING: Removing all Flags!\n"   
    
    count = Flag.count
    Flag.destroy_all
    
    puts "\n[MIGRATION FLAG-IMPORT] #{count} Flags removed.\n" 
    ActiveRecord::Base.logger.debug "\n[MIGRATION FLAG-IMPORT]  #{count} Flags removed.\n"      
    
  end


  def self.update_package_flags

    packages = DbPackage.find(:all)
        
    packages.each do |package|
      begin
        xml = @frontend.get_meta(:project => package.db_project.name, :package => package.name)
        axml = ActiveXML::Base.new(xml)
      
        old_flags = package.flags.size
        
        package.flag_compatibility_check( :package => axml )
        
        ['debuginfo'].each do |flagtype|
          package.update_flags( :package => axml, :flagtype => flagtype )
        end      
        
        package.old_flag_to_build_flag( :package => axml ) if axml.has_element? :disable      
        
        package.reload
        
        new_flags = package.flags.size
        
        #puts "[MIGRATION PACKAGE-FLAGUPDATE] #{package.db_project.name} \t #{package.name} \t old: #{old_flags} \t new: #{new_flags}"
        ActiveRecord::Base.logger.debug "[MIGRATION PACKAGE-FLAGUPDATE] #{package.db_project.name} \t #{package.name} \t old: #{old_flags} \t new: #{new_flags}"
      
      rescue Suse::Frontend::UnspecifiedError => error
        puts error.to_s
        ActiveRecord::Base.logger.debug error.to_s
      end        
    end    
  end

  
  def self.update_project_flags
    projects = DbProject.find(:all)

    projects.each do |project|
      begin
        if project.name != "deleted"
           xml = @frontend.get_meta(:project => project.name)
           axml = ActiveXML::Base.new(xml)      
      
           old_flags = project.flags.size
      
           project.flag_compatibility_check( :project => axml )
      
           ['debuginfo'].each do |flagtype|
               project.update_flags( :project => axml, :flagtype => flagtype )
             end          
           
           project.old_flag_to_build_flag( :project => axml ) if axml.has_element? :disable
             
           project.reload
           
           new_flags = project.flags.size
           
           puts "[MIGRATION PROJECT-FLAGUPDATE] #{project.name} \t old: #{old_flags} \t new: #{new_flags}"
           ActiveRecord::Base.logger.debug "[MIGRATION PROJECT-FLAGUPDATE] #{project.name} \t old: #{old_flags} \t new: #{new_flags}"
        end

      rescue Suse::Frontend::UnspecifiedError => error
        puts error.to_s
        ActiveRecord::Base.logger.debug error.to_s
      end
    end
     
  end
  
  
end



