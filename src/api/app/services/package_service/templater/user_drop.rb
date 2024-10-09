# https://github.com/Shopify/liquid/wiki/Introduction-to-Drops
module PackageService
  class Templater::UserDrop < ::Liquid::Drop
    def initialize(user)
      @user = user
      super()
    end

    def name
      @user.name
    end

    def login
      @user.login
    end

    def email
      @user.email
    end
  end
end
