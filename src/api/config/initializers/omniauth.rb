OmniAuth.config.path_prefix = '/session/sso'

path = Rails.root.join("config", "auth.yml")

CONFIG['sso_auth'] = Hash.new

if File.exist? path
  begin
      CONFIG['sso_auth'] = YAML.load_file(path)
  rescue Exception
      puts "Error while parsing config file #{path}"
  end

  Rails.application.config.middleware.use OmniAuth::Builder do
      CONFIG['sso_auth'].each do |name, options|
          options[:name] = name
          provider (options['strategy'] || name), options
          options['description'] ||= OmniAuth::Utils.camelize(name)
      end
  end
end
