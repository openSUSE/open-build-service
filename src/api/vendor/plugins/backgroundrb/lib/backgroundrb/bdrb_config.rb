require 'yaml'
require 'erb'
module BackgrounDRb
  class Config
    def self.parse_cmd_options(argv)
      options = { }

      OptionParser.new do |opts|
        script_name = File.basename($0)
        opts.banner = "Usage: #{$0} [options]"
        opts.separator ""
        opts.on("-e", "--environment=name", String,
                "Specifies the environment to operate under (test/development/production).",
                "Default: development") { |v| options[:environment] = v }
        opts.separator ""
        opts.on("-h", "--help",
                "Show this help message.") { $stderr.puts opts; exit }
        opts.separator ""
        opts.on("-v","--version",
                "Show version.") { $stderr.puts "1.1"; exit }
      end.parse!(argv)

      ENV["RAILS_ENV"] = options[:environment] if options[:environment]
    end

    def self.read_config(config_file)
      config = YAML.load(ERB.new(IO.read(config_file)).result)
      environment = ENV["RAILS_ENV"] || config[:backgroundrb][:environment] || "development"

      if respond_to?(:silence_warnings)
        silence_warnings do
          Object.const_set("RAILS_ENV",environment)
        end
      else
        Object.const_set("RAILS_ENV",environment)
      end

      ENV["RAILS_ENV"] = environment
      config
    end
  end
end

