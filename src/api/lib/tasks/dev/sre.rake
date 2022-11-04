namespace :dev do
  namespace :sre do
    # Run this task with: rails dev:sre:configure
    desc 'Configure the rails app to publish application health monitoring stats'
    task :configure do
      unless Rails.env.development?
        puts "You are running this rake task in #{Rails.env} environment."
        puts 'Please only run this task with RAILS_ENV=development'
        return
      end

      RakeSupport.copy_example_file('config/options.yml')
      options_yml = YAML.load_file('config/options.yml', aliases: true) || {}
      options_yml['development']['influxdb_hosts'] = ['influx']
      options_yml['development']['amqp_namespace'] = 'opensuse.obs'
      options_yml['development']['amqp_options'] = { host: 'rabbit', port: '5672', user: 'guest', pass: 'guest', vhost: '/' }
      options_yml['development']['amqp_exchange_name'] = 'pubsub'
      options_yml['development']['amqp_exchange_options'] = { type: :topic, persistent: 'true', passive: 'true' }
      File.write('config/options.yml', YAML.dump(options_yml))
    end
  end
end
