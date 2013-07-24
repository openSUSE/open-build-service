require 'opensuse/backend'

class Configuration < ActiveRecord::Base

  after_save :write_to_backend

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
                   :multiaction_notify_support => CONFIG['multiaction_notify_support'],
                   :change_password => CONFIG['change_passwd'],
                   :hide_private_options => CONFIG['hide_private_options'],
                   :gravatar => CONFIG['use_gravatar'],
                   :download_url => CONFIG['download_url'],
                   :ymp_url => CONFIG['ymp_url'],
                   :errbit_url => CONFIG['errbit_host'],
                   :bugzilla_url => CONFIG['bugzilla_host'],
                   :http_proxy => CONFIG['http_proxy'],
                   :no_proxy => nil,
                   :theme => CONFIG['theme'],
                 }
  ON_OFF_OPTIONS = [ :anonymous, :default_access_disabled, :allow_user_to_create_home_project, :disallow_group_creation, :change_password, :hide_private_options, :gravatar, :download_on_demand, :enforce_project_keys, :multiaction_notify_support ]
   
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

    def anonymous?
      Configuration.limit(1).pluck(:anonymous).first
    end
   
    def registration
      Configuration.limit(1).pluck(:registration).first
    end

    def download_url
      Configuration.limit(1).pluck(:download_url).first
    end

    def ymp_url
      Configuration.limit(1).pluck(:ymp_url).first
    end

  end

  def update_from_options_yml()
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


  def write_to_backend()
    if CONFIG['global_write_through']
      path = "/configuration"
      logger.debug "Write configuration information to backend..."
      Suse::Backend.put_source(path, self.render_axml)
    end
  end

  def render_axml()
    builder = Nokogiri::XML::Builder.new

    builder.configuration() do |configuration|
      keys = ::Configuration::OPTIONS_YML.keys
      keys.each do |key|
        next if self.send(key.to_s).nil?

        value = self.send(key.to_s)
        if ON_OFF_OPTIONS.include? key
          value = value ? "on" : "off"
        end
        configuration.send(key.to_s, value)
      end

      configuration.schedulers do |schedulers|
        Architecture.where(:available => 1).each do |arch|
          schedulers.arch( arch.name )
        end
      end
    end

    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
                              :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                            Nokogiri::XML::Node::SaveOptions::FORMAT
  end
end
