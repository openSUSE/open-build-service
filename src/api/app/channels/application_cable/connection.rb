module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      login = cookies.encrypted['_obs_api_session']['login']
      if login.nil?
        reject_unauthorized_connection
      else
        User.find_by!(login: login)
      end
    end
  end
end
