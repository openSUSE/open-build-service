# The OBS instance configuration
class Configuration < ApplicationRecord
  after_save :delayed_write_to_backend

  include CanRenderModel

  validates :name, :title, :description, presence: true

  # note: do not add defaults here. It must be either the options.yml content or nil
  # rubocop:disable Style/MutableConstant
  OPTIONS_YML = {
    title:                                nil,
    description:                          nil,
    name:                                 nil, # from BSConfig.pm
    download_on_demand:                   nil, # from BSConfig.pm
    enforce_project_keys:                 nil, # from BSConfig.pm
    anonymous:                            CONFIG['allow_anonymous'],
    registration:                         CONFIG['new_user_registration'],
    default_access_disabled:              CONFIG['default_access_disabled'],
    allow_user_to_create_home_project:    CONFIG['allow_user_to_create_home_project'],
    disallow_group_creation:              CONFIG['disallow_group_creation_with_api'],
    change_password:                      CONFIG['change_passwd'],
    obs_url:                              nil, # inital setup may happen in webui api controller
    api_url:                              nil,
    hide_private_options:                 CONFIG['hide_private_options'],
    gravatar:                             CONFIG['use_gravatar'],
    download_url:                         CONFIG['download_url'],
    ymp_url:                              CONFIG['ymp_url'],
    bugzilla_url:                         CONFIG['bugzilla_host'],
    http_proxy:                           CONFIG['http_proxy'],
    no_proxy:                             nil,
    cleanup_after_days:                   nil,
    theme:                                CONFIG['theme'],
    cleanup_empty_projects:               nil,
    disable_publish_for_branches:         nil,
    admin_email:                          nil,
    unlisted_projects_filter:             nil,
    unlisted_projects_filter_description: nil
  }
  # rubocop:enable Style/MutableConstant

  ON_OFF_OPTIONS = [:anonymous, :default_access_disabled,
                    :allow_user_to_create_home_project, :disallow_group_creation,
                    :change_password, :hide_private_options, :gravatar,
                    :download_on_demand, :enforce_project_keys,
                    :cleanup_empty_projects, :disable_publish_for_branches].freeze

  class << self
    def map_value(key, value)
      if key.in?(ON_OFF_OPTIONS)
        # make them boolean
        return value.in?([:on, ':on', 'on', 'true', true])
      end
      value
    end

    # Simple singleton implementation: Try to respond with the
    # the data from the first instance
    def method_missing(method_name, *args, &block)
      unless first
        Configuration.create(name: 'private', title: 'Open Build Service', description: 'Private OBS Instance')
      end
      if first.respond_to?(method_name)
        first.send(method_name, *args, &block)
      else
        super
      end
    end

    # Check if ldap group support is enabled?
    def ldapgroup_enabled?
      CONFIG['ldap_mode'] == :on && CONFIG['ldap_group_support'] == :on
    end
  end
  # End of class methods

  def ldap_enabled?
    CONFIG['ldap_mode'] == :on
  end

  def amqp_namespace
    CONFIG['amqp_namespace'] || 'opensuse.obs'
  end

  def passwords_changable?
    change_password && CONFIG['proxy_auth_mode'] != :on && CONFIG['ldap_mode'] != :on
  end

  def accounts_editable?
    (CONFIG['proxy_auth_mode'] != :on || (CONFIG['proxy_auth_mode'] == :on && CONFIG['proxy_auth_account_page'].present?)) && \
      CONFIG['ldap_mode'] != :on
  end

  def update_from_options_yml
    # strip the not set ones
    attribs = ::Configuration::OPTIONS_YML.clone
    attribs.each_key do |k|
      if attribs[k].nil?
        attribs.delete(k)
        next
      end

      attribs[k] = ::Configuration.map_value(k, attribs[k])
    end

    # special for api_url
    unless CONFIG['frontend_host'].blank? || CONFIG['frontend_port'].blank? || CONFIG['frontend_protocol'].blank?
      attribs["api_url"] = "#{CONFIG['frontend_protocol']}://#{CONFIG['frontend_host']}:#{CONFIG['frontend_port']}"
    end
    update_attributes(attribs)
    save!
  end

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
end

# == Schema Information
#
# Table name: configurations
#
#  id                                   :integer          not null, primary key
#  title                                :string(255)      default("")
#  description                          :text(65535)
#  created_at                           :datetime
#  updated_at                           :datetime
#  name                                 :string(255)      default("")
#  registration                         :string(12)       default("allow")
#  anonymous                            :boolean          default(TRUE)
#  default_access_disabled              :boolean          default(FALSE)
#  allow_user_to_create_home_project    :boolean          default(TRUE)
#  disallow_group_creation              :boolean          default(FALSE)
#  change_password                      :boolean          default(TRUE)
#  hide_private_options                 :boolean          default(FALSE)
#  gravatar                             :boolean          default(TRUE)
#  enforce_project_keys                 :boolean          default(FALSE)
#  download_on_demand                   :boolean          default(TRUE)
#  download_url                         :string(255)
#  ymp_url                              :string(255)
#  bugzilla_url                         :string(255)
#  http_proxy                           :string(255)
#  no_proxy                             :string(255)
#  theme                                :string(255)
#  obs_url                              :string(255)
#  cleanup_after_days                   :integer
#  admin_email                          :string(255)      default("unconfigured@openbuildservice.org")
#  cleanup_empty_projects               :boolean          default(TRUE)
#  disable_publish_for_branches         :boolean          default(TRUE)
#  default_tracker                      :string(255)      default("bnc")
#  api_url                              :string(255)
#  unlisted_projects_filter             :string(255)      default("^home:.+")
#  unlisted_projects_filter_description :string(255)      default("home projects")
#
