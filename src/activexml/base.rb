module ActiveXML
  class GeneralError < StandardError; end
  class NotFoundError < GeneralError; end
  class CreationError < GeneralError; end
  class ParseError < GeneralError; end

  class Base < LibXMLNode

    include ActiveXML::Config

    attr_reader :init_options
    attr_reader :cache_key

    @default_find_parameter = :name
    @@object_cache = {}

    class << self #class methods

      #transport object, gets defined according to configuration when Base is subclassed
      attr_reader :transport

      def inherited( subclass )
        # called when a subclass is defined
        #logger.debug "Initializing ActiveXML model #{subclass}"
        subclass.instance_variable_set "@default_find_parameter", @default_find_parameter
      end
      private :inherited

      # setup the default parameter for find calls. If the first parameter to <Model>.find is a string,
      # the value of this string is used as value f
      def default_find_parameter( sym )
        @default_find_parameter = sym
      end

      def setup(transport_object)
        super()
        @@transport = transport_object
        #logger.debug "--> ActiveXML successfully set up"
        true
      end

      def error
        @error
      end

      def prepare_args( args )
        if args[0].kind_of? String
          args[1] ||= {}
          first_arg = args.shift
          hash = args.shift
          hash[@default_find_parameter] = first_arg
          args.insert(0, hash)
        end
        if args[0].kind_of? Hash
          hash = Hash.new
          args[0].each do |key, value|
            if key.nil? or value.nil?
              logger.debug "nil value given #{args.inspect}"
              next
            end
            if value.kind_of? Array
              hash[key.to_sym] = value
            else
              hash[key.to_sym] = value.to_s 
            end
          end
          args[0] = hash
        end

        #logger.debug "prepared find args: #{args.inspect}"
        return args
      end

      def calc_key( args )
        #logger.debug "Cache key for #{args.inspect}"
        self.name + "_" + Digest::MD5.hexdigest( "2" + args.to_s )
      end

      def free_object_cache
	@@object_cache = {}
      end

      def find_priv(cache_time, *args )
        cache_key = calc_key( args )
        if cache_time
          obj = @@object_cache[cache_key]
          return obj if obj
        end

        #FIXME: needs cleanup
        #TODO: factor out xml stuff to ActiveXML::Node
        #logger.debug "#{self.name}.find( #{cache_time.inspect}, #{args.join(', ')})"

        #TODO: somehow we need to set the transport again, as it was not set when subclassing.
        # only happens with rails >= 2.3.4 and config.cache_classes = true
        transport = config.transport_for(self.name.downcase.to_sym)
        raise "No transport defined for model #{self.name}" unless transport

	objhash = nil
        begin
          if cache_time
            objdata, params, objhash = Rails.cache.fetch(cache_key, :expires_in => cache_time) do
              objdata, params = transport.find( self, *(prepare_args(args)) )
	      obj = self.new( objdata )
	      [objdata, params, obj.to_hash]
            end
          else
            objdata, params = transport.find( self, *(prepare_args(args)) )
          end
          obj = self.new( objdata ) unless obj
          obj.instance_variable_set( '@cache_key', cache_key ) if cache_key
          obj.instance_variable_set( '@init_options', params )
	  obj.instance_variable_set( '@hash_cache', objhash) if objhash
	  @@object_cache[cache_key] = obj
          return obj
        rescue ActiveXML::Transport::NotFoundError
          logger.debug "#{self.name}.find( #{args.map {|a| a.inspect}.join(', ')} ) did not find anything, return nil"
          return nil
        end
      end

      def find( *args )
        find_priv(nil, *args )
      end

      def find_cached( *args )
        expires_in = 30.minutes
        if args.last.kind_of?(Hash) and args.last[:expires_in]
          expires_in = args.last[:expires_in] 
          args.last.delete :expires_in
        end
        find_priv(expires_in, *args)
      end

      def find_hashed( *args ) 
        ret = find_cached( *args )
        return {} unless ret
        ret.to_hash
      end

      def free_cache( *args )
        # modify copy of args as it might be still used in the calling method
        free_args = args.dup
        options = free_args.last if free_args.last.kind_of?(Hash)
        if options && options[:expires_in] 
          free_args[free_args.length-1] = free_args.last.dup
          free_args.last.delete :expires_in
        end
        key = calc_key( free_args )
        @@object_cache.delete key
        Rails.cache.delete( key )
      end

    end #class methods

    def initialize( data, opt={} )
      super(data)
      opt = data if data.kind_of? Hash and opt.empty?
      @init_options = opt
    end

    def name
      method_missing( :name )
    end

    def marshal_dump
      raise "you don't want to put it in cache - never!"
    end

    def save(opt={})
      transport = TransportMap.transport_for(self.class.name.downcase.to_sym)
      if opt[:create]
        @raw_data = transport.create self, opt
        @data = nil
	@to_hash = nil
      else
        transport.save self, opt
        Rails.cache.delete @cache_key if @cache_key
      end
      return true
    end

    def delete(opt={})
      #logger.debug "Delete #{self.class}, opt: #{opt.inspect}"
      transport = TransportMap.transport_for(self.class.name.downcase.to_sym)
      transport.delete self, opt
      Rails.cache.delete @cache_key if @cache_key
      return true
    end

  end
end
