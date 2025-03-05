require 'api_error'

class UnregisteredUser < User
  class ErrRegisterSave < APIError
  end

  # Raises an exception if registration is disabled for a user
  # Returns true if a user can register
  def self.can_register?
    # No registering if we use an authentication proxy
    if ::Configuration.proxy_auth_mode_enabled?
      logger.debug 'Someone tried to register with "proxy_auth_mode" turned on'
      err_msg = if CONFIG['proxy_auth_register_page'].blank?
                  'Sorry, please sign up using the authentication proxy'
                else
                  "Sorry, please sign up using #{CONFIG['proxy_auth_register_page']}"
                end
      raise ErrRegisterSave, err_msg
    end

    # Turn off registration if its disabled
    if ::Configuration.registration == 'deny'
      return true if User.admin_session?

      logger.debug 'Someone tried to register but its disabled'
      raise ErrRegisterSave, 'Sorry, sign up is disabled'
    end

    # Turn on registration if it's enabled
    return true if %w[allow confirmation].include?(::Configuration.registration)

    # This shouldn't happen, but disable registration by default.
    logger.debug "Huh? This shouldn't happen. UnregisteredUser.can_register ran out of options"
    raise ErrRegisterSave, 'Sorry, sign up is disabled'
  end

  def self.register(opts)
    can_register?

    opts[:note] = nil unless User.admin_session?
    state = ::Configuration.registration == 'allow' ? 'confirmed' : 'unconfirmed'

    newuser = User.new(
      realname: opts[:realname] || '',
      login: opts[:login],
      password: opts[:password],
      password_confirmation: opts[:password_confirmation],
      email: opts[:email],
      state: state,
      adminnote: opts[:note]
    )

    raise ErrRegisterSave, "Could not save the registration, details: #{newuser.errors.full_messages.to_sentence}" unless newuser.save

    return unless newuser.state == 'unconfirmed'

    raise ErrRegisterSave, 'Thank you for signing up! An admin has to confirm your account now. Please be patient.'
  end
end

# == Schema Information
#
# Table name: users
#
#  id                            :integer          not null, primary key
#  adminnote                     :text(65535)
#  biography                     :string(255)      default("")
#  censored                      :boolean          default(FALSE), not null, indexed
#  color_theme                   :integer          default("system"), not null
#  deprecated_password           :string(255)      indexed
#  deprecated_password_hash_type :string(255)
#  deprecated_password_salt      :string(255)
#  email                         :string(200)      default(""), not null
#  ignore_auth_services          :boolean          default(FALSE)
#  in_beta                       :boolean          default(FALSE), indexed
#  in_rollout                    :boolean          default(TRUE), indexed
#  last_logged_in_at             :datetime
#  login                         :text(65535)      indexed
#  login_failure_count           :integer          default(0), not null
#  password_digest               :string(255)
#  realname                      :string(200)      default(""), not null
#  rss_secret                    :string(200)      indexed
#  state                         :string           default("unconfirmed"), indexed
#  created_at                    :datetime
#  updated_at                    :datetime
#  owner_id                      :integer
#
# Indexes
#
#  index_users_on_censored    (censored)
#  index_users_on_in_beta     (in_beta)
#  index_users_on_in_rollout  (in_rollout)
#  index_users_on_rss_secret  (rss_secret) UNIQUE
#  index_users_on_state       (state)
#  users_login_index          (login) UNIQUE
#  users_password_index       (deprecated_password)
#
