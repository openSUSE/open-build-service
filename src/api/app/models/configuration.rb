# The OBS instance configuration
class Configuration < ApplicationRecord
  has_one_attached :logo
  after_save :invalidate_cache, :delayed_write_to_backend

  include CanRenderModel
  include ConfigurationConstants

  validates :name, :title, :description, presence: true
  validates :admin_email, :api_url, :bugzilla_url, :contact_name, :contact_url, :default_tracker, :download_url, :http_proxy, :name, :no_proxy, :obs_url, :theme, :title,
            :tos_url, :unlisted_projects_filter, :unlisted_projects_filter_description, :ymp_url, length: { maximum: 255 }
  validates :description, :code_of_conduct, length: { maximum: 65_535 }

  class << self
    def accounts_editable?
      !proxy_auth_mode_enabled? || CONFIG['proxy_auth_account_page'].present?
    end

    def amqp_namespace
      CONFIG['amqp_namespace'] || 'opensuse.obs'
    end

    def fetch
      Rails.cache.fetch('configurations/1', expires_in: 1.day) do
        first
      end
    end

    def map_value(key, value)
      # make them boolean
      return value.in?([:on, ':on', 'on', 'true', true]) if key.in?(::Configuration::ON_OFF_OPTIONS)

      value
    end

    # Simple singleton implementation: Try to respond with the
    # the data from the first instance
    def method_missing(method_name, ...)
      if Configuration.column_names.include?(method_name.to_s) || Configuration.attachment_reflections.key?(method_name.to_s)
        fetch.send(method_name, ...)
      elsif Configuration.new.methods.include?(method_name)
        first.send(method_name, ...)
      else
        super
      end
    end

    def passwords_changable?
      change_password && !proxy_auth_mode_enabled?
    end

    def proxy_auth_mode_enabled?
      logger.info 'Warning: You are using the deprecated ichain_mode setting in config/options.yml' if CONFIG['ichain_mode'].present?

      return false unless Configuration::PROXY_MODE_ENABLED_VALUES.include?(CONFIG['proxy_auth_mode']) || CONFIG['ichain_mode'] == :on

      unless CONFIG['proxy_auth_login_page'].present? && CONFIG['proxy_auth_logout_page'].present?
        logger.info 'Warning: You enabled proxy_auth_mode in config/options.yml but did not set the required proxy_auth_login_page/proxy_auth_logout_page options'
        return false
      end

      true
    end

    # overwrite update function as the one in active record expects an id
    def update(opts)
      Configuration.first.update(opts)
    end
  end
  # End of class methods

  # We don't really care about consistency at this point.
  # We use the delayed job so it can fail while seeding
  # the database or in migrations when there is no backend
  # running
  def delayed_write_to_backend
    ConfigurationWriteToBackendJob.perform_later(id)
  end

  def write_to_backend
    return unless CONFIG['global_write_through']

    logger.debug 'Writing configuration.xml to backend...'
    Backend::Api::Server.write_configuration(render_xml)
  end

  def invalidate_cache
    Rails.cache.delete('configurations/1')
  end
end

# == Schema Information
#
# Table name: configurations
#
#  id                                   :integer          not null, primary key
#  admin_email                          :string(255)      default("unconfigured@openbuildservice.org")
#  allow_user_to_create_home_project    :boolean          default(TRUE)
#  anonymous                            :boolean          default(TRUE)
#  api_url                              :string(255)
#  bugzilla_url                         :string(255)
#  change_password                      :boolean          default(TRUE)
#  cleanup_after_days                   :integer
#  cleanup_empty_projects               :boolean          default(TRUE)
#  code_of_conduct                      :text(65535)
#  contact_name                         :string(255)
#  contact_url                          :string(255)
#  default_access_disabled              :boolean          default(FALSE)
#  default_tracker                      :string(255)      default("bnc")
#  description                          :text(65535)
#  disable_publish_for_branches         :boolean          default(TRUE)
#  disallow_group_creation              :boolean          default(FALSE)
#  download_on_demand                   :boolean          default(TRUE)
#  download_url                         :string(255)
#  enforce_project_keys                 :boolean          default(FALSE)
#  gravatar                             :boolean          default(TRUE)
#  hide_private_options                 :boolean          default(FALSE)
#  http_proxy                           :string(255)
#  name                                 :string(255)      default("")
#  no_proxy                             :string(255)
#  obs_url                              :string(255)      default("https://unconfigured.openbuildservice.org")
#  registration                         :string           default("allow")
#  theme                                :string(255)
#  title                                :string(255)      default("")
#  tos_url                              :string(255)
#  unlisted_projects_filter             :string(255)      default("^home:.+")
#  unlisted_projects_filter_description :string(255)      default("home projects")
#  ymp_url                              :string(255)
#  created_at                           :datetime
#  updated_at                           :datetime
#
