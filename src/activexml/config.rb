require 'uri'

module ActiveXML
  module Config

    DEFAULTS = Hash.new

    # the xml backend used for parsing
    DEFAULTS[:xml_backend] = "rexml"

    # available transport plugins
    DEFAULTS[:transport_plugins] = "rest"

    # if transport plugins should be used (deprecated)
    # TODO: check code for usage of this variable/remove it
    DEFAULTS[:use_transport_plugins] = false

    # if xml should be parsed on load (false) or on first element/attribute access (true)
    DEFAULTS[:lazy_evaluation] = false

    # globally deactivate write_through to backend on PUT requests
    DEFAULTS[:global_write_through] = true

    def self.append_features(base)
      super
      base.extend ClassMethods
    end

    module ClassMethods
      # defines ActiveXML::Base.config. Returns the ActiveXML::Config module from which you
      # can get/set the current configuration by using the dynamically added accessors.
      # ActiveXML::Base.config can also be called with a block which gets passed the Config object.
      # The block style call is typically used from the environment files in ${RAILS_ROOT}/config
      #
      # Example:
      # ActiveXML::Base.config do |conf|
      #   conf.xml_backend = "rexml"
      # end
      #
      # Configuration options can also be accessed by calling the accessor methods directly on
      # ActiveXML::Config :
      #
      # Example:
      # ActiveXML::Config.xml_backend = "xml_smart"
      #
      def config
        yield(ActiveXML::Config) if block_given?
        return ActiveXML::Config
      end
    end

    class TransportMap

      # stores the default server for a specific protocol
      # example:
      # @default_servers[:rest] = "localhost:3001"
      @default_servers = Hash.new

      # maps transport classes to protocol names
      # example:
      # @transport_class_map[:rest] = ActiveXML::Transport::Rest
      @transport_class_map = Hash.new

      # stores instanced transport objects per model
      @transport_obj_map = Hash.new

      # stores mapping information
      # key: symbolified model name
      # value: hash with keys :target_uri and :opt (arguments to connect method)
      @mapping = Hash.new

      class << self
        def logger
          ActiveXML::Config.logger
        end

        def default_server( transport, location )
          @default_servers ||= Hash.new
          logger.debug "default_server for #{transport.inspect} models: #{location}"
          @default_servers[transport.to_s] = location
        end

        def connect( model, target, opt={} )
          opt.each do |key,value|
            # workaround for :write_through option. fix would be to not configure
            # additional routes and options using the same hash
            next if key == :write_through
            opt[key] = URI(opt[key])
            replace_server_if_needed( opt[key] )
          end

          uri = URI( target )
          @transport_obj_map[model] = spawn_transport( uri.scheme, opt )
          replace_server_if_needed( uri )
          logger.debug "setting up transport for model #{model}: #{uri} opts: #{opt}"
          @mapping[model] = {:target_uri => uri, :opt => opt}
        end

        def replace_server_if_needed( uri )
          if not uri.host
            uri.scheme, uri.host, uri.port = get_default_server(uri.scheme)
          end
        end

        def spawn_transport( transport, opt={} )
          if @transport_class_map and @transport_class_map.has_key? transport.to_s
            @transport_class_map[transport.to_s].spawn( transport, opt )
          else
            raise "Unable to spawn transport object for transport '#{transport}'"
          end
        end

        def get_default_server( transport )
          ds = @default_servers[transport.to_s]
          ds_uri = URI.parse(ds)
          return ds_uri.scheme, ds_uri.host, ds_uri.port
        rescue
          return nil, ds, nil
        end

        def register_transport( klass, proto )
          @transport_class_map ||= Hash.new
          if @transport_class_map.has_key? proto
            #raise "Transport for protocol '#{proto}' already registered"
          else
            @transport_class_map[proto] = klass
          end
        end

        def transport_for( model )
          @transport_obj_map ||= Hash.new
          @transport_obj_map[model]
        end

        def target_for( model )
          #logger.debug "retrieving target_uri for model '#{model.inspect}'"
          raise "Model #{model.inspect} is not configured" if not @mapping.has_key? model
          @mapping[model][:target_uri]
        end

        def options_for( model )
          #logger.debug "retrieving option hash for model '#{model.inspect}'"
          @mapping[model][:opt]
        end

        def debug_dump
          require 'pp'
          pp "Default servers: " + @default_servers
          pp "Transport class map: " + @transport_class_map
          pp "Transport obj map: " + @transport_obj_map
          pp "Mapping: " + @mapping
        end

      end
    end

    class << self

      # access the logger object. All ActiveXML modules should use this method
      # instead of using RAILS_DEFAULT_LOGGER to remain independent of rails
      def logger
        @log_obj || RAILS_DEFAULT_LOGGER
      end

      # defines the logger object used throughout ActiveXML modules
      def logger=( log_obj )
        @log_obj = log_obj
      end

      def debug_dump
        puts "config data:"
        @config.each do |k,v|
          puts "#{k}: #{v}"
        end unless @config.nil?
        puts "Transport Map:"
        TransportMap.debug_dump
      end

      def setup_transport
        yield TransportMap
      end

      def transport_for( model )
        TransportMap.transport_for model
      end

      def register_transport( klass, proto )
        TransportMap.register_transport klass, proto
      end

      def method_missing( sym, *args ) #:nodoc:
        attr_name = sym.to_s =~ /=$/ ? sym.to_s.sub(/.$/, '').to_sym : sym
        if DEFAULTS.has_key? attr_name
          @config ||= Hash.new
          add_config_accessor(attr_name) unless self.respond_to? attr_name
          __send__( sym, *args )
        else
          super
        end
      end

      def add_config_accessor(sym) #:nodoc:
        instance_eval <<-END_EVAL
          def #{sym}
            if @config.has_key? #{sym.inspect}
              return @config[#{sym.inspect}]
            else
              return DEFAULTS[#{sym.inspect}]
            end
          end

          def #{sym}=(val)
            @config[#{sym.inspect}] = val
          end
        END_EVAL
      end
    end
  end
end
