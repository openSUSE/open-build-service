# Makes proxy mode possible through the devise_ichain_authenticatable gem.
module IchainAuthenticatable
  extend ActiveSupport::Concern

  class_methods do
    # Maps a proxy (iChain) username to a user. Creates the user when registration allows it.
    # attributes: :email, :firstname, :lastname (nil values are ignored).
    # Returns nil when the user does not exist and registration is denied.
    def for_ichain_username(login, attributes = {})
      user = find_by(login: login)

      unless user
        return if ::Configuration.registration == 'deny'

        user = create_user_with_fake_pw!(login: login, state: default_user_state)
      end

      user.update!({ email: attributes[:email],
                     realname: proxy_realname(attributes[:firstname], attributes[:lastname]) }.compact)
      user
    end

    def proxy_realname(firstname, lastname)
      return if firstname.blank? && lastname.blank?

      "#{firstname} #{lastname}".strip.force_encoding('UTF-8')
    end
    private :proxy_realname
  end
end
