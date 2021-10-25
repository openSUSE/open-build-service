class CheckUpgradeJob < ApplicationJob
  
  def perform
    Rails.logger.info "Running check upgrade job ...."
    #Get OBS Instance Super User
    user = User.find_by(realname: 'OBS Instance Superuser', state: 'confirmed')
    return if user.blank?
    #Get all projects
    projects = Project.all
    projects.each do |project|
      #Get all packages by project
      packages = project.packages
      packages.each do |package|
        #Get all services
        document = Backend::Api::Sources::Package.service(project.name, package.name)
        if document.present?
          Xmlhash.parse(document).elements('service').each do |service|
            if service['name'] == 'check_upgrade'
              Rails.logger.info "Check_upgrade found!"
              Rails.logger.info "Running all services for "
              Rails.logger.info package.name
              Backend::Api::Sources::Package.run_service(project.name, package.name, user.login)
            end  
          end
        end
      end
    end
    Rails.logger.info "Check upgrade job finished!"
  end

end