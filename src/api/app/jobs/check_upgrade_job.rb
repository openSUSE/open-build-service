class CheckUpgradeJob < ApplicationJob

  
  def perform(project_id, package_id=nil)
    
    logger.debug "Running check upgrade job ...."

    user = User.session!.login

    if package_id.present?    
      packages = Package.all.where(id: package_id, project_id: project_id)
    else
      packages = Package.all.where(project_id: project_id)
    end

    packages.each do |package|
      #result = Backend::Api::Sources::Package.check_upgrade(package.project.name, package.name, user)
      #Should be here somethig like: 
      #checkupgrade = package.checkupgrade
      #result = Backend::Api::Sources::Package.check_upgrade2(checkupgrade.urlsrc, checkupgrade.regexurl, ...., user)
      #Tsting parameter
      result = Backend::Api::Sources::Package.check_upgrade(
        'https://archive.eclipse.org/eclipse/downloads/', 
        'drops[\w]*/R-[\d]+[.][\w]*[.]*[\w]*-[\w]+/', 
        '[\d]+[.][\w]*[.]*[\w]*', 
        '4.7.1',
        '.', 
        'false', 
        user)

      puts "Result = ", result
    end

    logger.debug "Check upgrade job finished!"

  end

  private

  def logger
    Rails.logger
  end

  def get_conf_params

  end

  def set_conf_params

  end

end