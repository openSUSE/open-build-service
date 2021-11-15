class CheckUpgradeJob < ApplicationJob
  
  def perform
    affected_rows = 0 
    is_error = false
    
    logger.debug "Running check upgrade job ...."

    #Get OBS Instance Super User
    user = User.find_by(realname: 'OBS Instance Superuser', state: 'confirmed')
    if ! user.present?
      raise "OBS Instance Super User not found !"
    end

    #Retrieve the configuration parameters (limit and offset)
    limit, offset = get_conf_params
    #Count the records
    check_upgrades_count = PackageCheckUpgrade.order(:package_id).count
    if check_upgrades_count > 0
      #Retrieve all "check upgrade" by limit and offset ordered by package_id
      check_upgrades = PackageCheckUpgrade.order(:package_id).limit(limit).offset(offset)
      
      check_upgrades.each do |check_upgrade|
        affected_rows += 1

        #Execute check
        result = check_upgrade.run_checkupgrade(user.login)
        if ! result.present?
          logger.error "An error has occurred in run_checkupgrade(). Result is not defined!"
          return
        end
        #Set state and output
        check_upgrade.set_output_and_state_by_result(result)

        begin
          #Update the data
          check_upgrade.update!(output: check_upgrade.output, state: check_upgrade.state)

          #FIXME adding the send email

        rescue => exception
          logger.error "Update failed!"
          exception.message
          exception.backtrace
          is_error = true
        ensure

          #FIXME here always update the offset in yaml file whatever happens.....

        end

      end
    end

    logger.debug "Check upgrade job finished!"

  end

  private

  def logger
    Rails.logger
  end

  def get_conf_params
    check_upgrade_param = YAML.load_file("#{Rails.root}/config/check_upgrade.yml")
    if ! check_upgrade_param.present?
      raise "Error: check_upgrade.yml not found!"
    else
      limit = check_upgrade_param['checkupgrade']['limit']
      offset = check_upgrade_param['checkupgrade']['offset'] 
      if ! limit.present? or ! offset.present?
        raise "Error: limit and offset not correctly set in #{Rails.root}/config/check_upgrade.yml!"
      else
        return limit, offset
      end 
    end
  end

  def set_conf_params(offset)

  end

end