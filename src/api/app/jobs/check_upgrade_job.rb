class CheckUpgradeJob < ApplicationJob
  
  def perform(project_id, package_id=nil)
    
    Rails.logger.debug "Running check upgrade job ...."

    user = User.session!.login

    if package_id.present?    
      packages = Package.all.where(id: package_id, project_id: project_id)
    else
      packages = Package.all.where(project_id: project_id)
    end

    packages.each do |package|
      result = Backend::Api::Sources::Package.check_upgrade(package.project.name, package.name, user)
      puts "Result = ", result
    end

    Rails.logger.info "Check upgrade job finished!"
    
  end

end