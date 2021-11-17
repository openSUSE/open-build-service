# TODO: Please overwrite this comment with something explaining the model target
class PackageCheckUpgrade < ApplicationRecord

  STATE_UPGRADE = "upgrade"
  STATE_UPTODATE = "uptodate"
  STATE_ERROR = "error"

  def set_output_and_state_by_result(result)
    if result.present?
      if result.start_with?('Error:')
        self.state = STATE_ERROR
        self.output = result.gsub("\n", "\\n")
      else
        if result.start_with?('Available')
          self.state = STATE_UPGRADE 
        elsif result.start_with?('The package')
          self.state = STATE_UPTODATE
        end
        self.output = result.gsub("\n", "")
      end
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