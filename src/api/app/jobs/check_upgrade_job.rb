class CheckUpgradeJob < ApplicationJob
  
  def perform(project_id, package_id)
    Rails.logger.debug "Running check upgrade job ...."
    puts "Project id = " , project_id
    puts "Package id = " , package_id
    puts "User session = " , User.session!.login

    #FIXME


    Rails.logger.info "Check upgrade job finished!"
  end

end