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
          #This error never should have to happen. I check it anyway
          raise "An error has occurred in run_checkupgrade(). Result is not defined!"
        end
        #Set state and output
        check_upgrade.set_output_and_state_by_result(result)

        begin
          #Serialize the access on the record to avoid eventual race condition with "front end"
          check_upgrade_db = PackageCheckUpgrade.lock.find_by(id: check_upgrade.id)
          
          #Update the data
          check_upgrade_db.update!(output: check_upgrade.output, state: check_upgrade.state, 
                                   updated_at: Time.now)
          #Email
          if check_upgrade_db.send_email and check_upgrade_db.state != PackageCheckUpgrade::STATE_UPTODATE
            CheckUpgradeMailer.with(packageCheckUpgrade: check_upgrade_db).send_email.deliver_now
          end

        rescue => ex
          logger.error "Exception in check upgrade job!"
          logger.error ex.message
          logger.error ex.backtrace
          is_error = true
          break
        end

      end

      #Offset management
      if is_error
        #If something went wrong, restart from this offset
        offset += (affected_rows - 1)
      else
        #Process new offset
        offset += affected_rows
        if offset == check_upgrades_count
          #The records are terminated, restart from zero
          offset = 0
        end     
      end
      #Update offset
      set_conf_params(offset)

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
      raise "Error in get_conf_params: check_upgrade.yml not found!"
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
    check_upgrade_param = YAML.load_file("#{Rails.root}/config/check_upgrade.yml")
    if ! check_upgrade_param.present?
      raise "Error in set_conf_params: check_upgrade.yml not found!"
    else
      check_upgrade_param['checkupgrade']['offset'] = offset
      #Store
      File.open("#{Rails.root}/config/check_upgrade.yml", "w") { |file| file.write check_upgrade_param.to_yaml } 
    end
  end

end