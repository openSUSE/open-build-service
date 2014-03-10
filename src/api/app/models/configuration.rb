require 'opensuse/backend'

class Configuration < ActiveRecord::Base

  after_save :delayed_write_to_backend

  include CanRenderModel

  OPTIONS_YML =  { :title => nil,
                   :description => nil,
                   :name => nil,                     # from BSConfig.pm
                   :download_on_demand => nil,       # from BSConfig.pm
                   :enforce_project_keys => nil,     # from BSConfig.pm
                   :anonymous => CONFIG['allow_anonymous'],
                   :registration => CONFIG['new_user_registration'],
                   :default_access_disabled => CONFIG['default_access_disabled'],
                   :allow_user_to_create_home_project => CONFIG['allow_user_to_create_home_project'],
                   :disallow_group_creation => CONFIG['disallow_group_creation_with_api'],
                   :change_password => CONFIG['change_passwd'],
                   :hide_private_options => CONFIG['hide_private_options'],
                   :gravatar => CONFIG['use_gravatar'],
                   :download_url => CONFIG['download_url'],
                   :ymp_url => CONFIG['ymp_url'],
                   :bugzilla_url => CONFIG['bugzilla_host'],
                   :http_proxy => CONFIG['http_proxy'],
                   :no_proxy => nil,
                   :cleanup_after_days => nil,
                   :theme => CONFIG['theme'],
                   :admin_email => nil,
                 }
  ON_OFF_OPTIONS = [ :anonymous, :default_access_disabled, :allow_user_to_create_home_project, :disallow_group_creation, :change_password, :hide_private_options, :gravatar, :download_on_demand, :enforce_project_keys ]
   
  class << self
    def map_value(key, value)
      if ON_OFF_OPTIONS.include? key
        # make them boolean
        if [ :on, ":on", "on", "true", true ].include? value
           value = true
        else
           value = false
        end
      end
      return value
    end

    def first
      super # caching in instance variables is evil for testing
    end

    def anonymous?
      first.anonymous
    end
   
    def registration
      first.registration
    end

    def download_url
      first.download_url
    end

    def ymp_url
      first.ymp_url
    end

    def use_gravatar?
      first.gravatar
    end

    # Check if ldap group support is enabled?
    def ldapgroup_enabled?
      CONFIG['ldap_mode'] == :on && CONFIG['ldap_group_support'] == :on
    end

  end

  def update_from_options_yml
    # strip the not set ones
    attribs = ::Configuration::OPTIONS_YML.clone
    attribs.keys.each do |k|
      if attribs[k].nil?
        attribs.delete(k)
        next
      end

      attribs[k] = ::Configuration::map_value(k, attribs[k])
    end

    self.update_attributes(attribs)
    self.save!
  end

  def delayed_write_to_backend
    self.delay.write_to_backend
  end

  def write_to_backend
    if CONFIG['global_write_through']
      path = "/configuration"
      logger.debug "Write configuration information to backend..."
      Suse::Backend.put_source(path, self.render_xml)
    end
  end

end
