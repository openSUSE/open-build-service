require 'opensuse/backend'
# The OBS instance configuration
class Configuration < ApplicationRecord
  after_save :delayed_write_to_backend

  include CanRenderModel

  validates :name, :title, :description, presence: true

  OPTIONS_YML = {
    title:                                nil,
    description:                          nil,
    name:                                 nil, # from BSConfig.pm
    download_on_demand:                   nil, # from BSConfig.pm
    enforce_project_keys:                 false, # from BSConfig.pm
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
    unlisted_projects_filter:             '^home:.+',
    unlisted_projects_filter_description: 'home projects'
  }
  ON_OFF_OPTIONS = [:anonymous, :default_access_disabled,
                    :allow_user_to_create_home_project, :disallow_group_creation,
                    :change_password, :hide_private_options, :gravatar,
                    :download_on_demand, :enforce_project_keys,
                    :cleanup_empty_projects, :disable_publish_for_branches]

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
    delay.write_to_backend
  end

  def write_to_backend
    if CONFIG['global_write_through']
      path = '/configuration'
      logger.debug 'Writing configuration.xml to backend...'
      Suse::Backend.put_source(path, render_xml)
    end
  end
end
