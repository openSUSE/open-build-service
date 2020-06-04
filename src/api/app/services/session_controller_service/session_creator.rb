module SessionControllerService
  class SessionCreator
    attr_accessor :user

    def initialize(params)
      @username = params.fetch(:username, '')
      @password = params.fetch(:password, '')
    end

    def valid?
      return true if @username.present? && @password.present?

      false
    end

    def exist?
      @user ||= User.find_with_credentials(@username, @password)
      @user.present?
    end
  end
end
