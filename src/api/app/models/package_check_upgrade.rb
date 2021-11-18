# TODO: Please overwrite this comment with something explaining the model target
class PackageCheckUpgrade < ApplicationRecord

  STATE_UPGRADE = "upgrade"
  STATE_UPTODATE = "uptodate"
  STATE_ERROR = "error"

  def set_output_and_state_by_result(result)
    if result.present?
      case 
        when result.start_with?("Error:")
          self.state = STATE_ERROR
        when result.start_with?("Available")  
          self.state = STATE_UPGRADE 
        when result.start_with?("The package")
          self.state = STATE_UPTODATE
        else
          raise "Exception in set_output_and_state_by_result(). Result has an unrecognized value!"
      end
      self.output = result.gsub("\n", "")
    else
      self.state = STATE_ERROR
      self.output = nil
    end
  end

  def run_checkupgrade(user_login)
    result = Backend::Api::Sources::PackageCheckUpgrade.check_upgrade(urlsrc, regexurl, regexver, currentver, separator, "false", user_login)
    return result
  end
  
end