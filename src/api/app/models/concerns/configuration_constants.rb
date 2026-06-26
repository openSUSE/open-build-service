module ConfigurationConstants
  extend ActiveSupport::Concern

  # note: do not add defaults here. It must be either the options.yml content or nil
  # rubocop:disable Style/MutableConstant
  # FIXME: The hash keys are outputted in the error message of the PUT endpoint in the configurations_controller.
  #        To remove the confusion, the hash keys should have the same name as the config options from which they take their value.
  OPTIONS_YML = {
    title: nil,
    description: nil,
    name: nil, # from BSConfig.pm
    download_on_demand: nil, # from BSConfig.pm
    enforce_project_keys: nil, # from BSConfig.pm
    anonymous: CONFIG['allow_anonymous'],
    registration: CONFIG['new_user_registration'],
    default_access_disabled: CONFIG['default_access_disabled'],
    allow_user_to_create_home_project: CONFIG['allow_user_to_create_home_project'],
    disallow_group_creation: CONFIG['disallow_group_creation_with_api'],
    change_password: CONFIG['change_passwd'],
    obs_url: nil, # inital setup may happen in webui api controller
    api_url: nil,
    hide_private_options: CONFIG['hide_private_options'],
    gravatar: CONFIG['use_gravatar'],
    download_url: CONFIG['download_url'],
    ymp_url: CONFIG['ymp_url'],
    bugzilla_url: CONFIG['bugzilla_host'],
    http_proxy: CONFIG['http_proxy'],
    no_proxy: nil,
    cleanup_after_days: nil,
    theme: CONFIG['theme'],
    cleanup_empty_projects: nil,
    disable_publish_for_branches: nil,
    admin_email: nil,
    unlisted_projects_filter: nil,
    unlisted_projects_filter_description: nil,
    tos_url: nil,
    code_of_conduct: nil,
    default_tracker: nil
  }
  # rubocop:enable Style/MutableConstant

  ON_OFF_OPTIONS = %i[anonymous default_access_disabled allow_user_to_create_home_project disallow_group_creation
                      change_password hide_private_options gravatar download_on_demand enforce_project_keys
                      cleanup_empty_projects disable_publish_for_branches].freeze

  PROXY_MODE_ENABLED_VALUES = %i[on ichain mellon].freeze
end
