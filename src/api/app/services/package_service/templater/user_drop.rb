# https://github.com/Shopify/liquid/wiki/Introduction-to-Drops
module PackageService
  class Templater::UserDrop < ::Liquid::Drop
    def initialize(user)
      @user = user
      super()
    end

    delegate :name, to: :@user

    delegate :login, to: :@user

    delegate :email, to: :@user
  end
end
