class CheckUpgradeJob < ApplicationJob
  
  def perform
    puts "Running check upgrade job ...."
    #Get OBS Instance Super User
    user = User.find_by(realname: 'OBS Instance Superuser', state: 'confirmed')
    if !user.nil?
      #Get all projects
      projects = Project.all
      projects.each do |project|
        #Get all packages by project
        packages = Package.all.where(project_id: project.id)
        packages.each do |package|
          #Get all services
          document = Backend::Api::Sources::Package.service(project.name, package.name)
          if !document.nil?
            Xmlhash.parse(document).elements('service').each do |service|
              if service['name'] == 'check_upgrade'
                print "Check_upgrade found!\n"
                print "Running all services for "
                print package.name
                print "....\n"
                Backend::Api::Sources::Package.run_service(project.name, package.name, user.login)
              end  
            end
          end
        end
      end
    end
    puts "Check upgrade job finished!"
  end

end