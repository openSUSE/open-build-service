require 'nokogiri'
require 'xmlhash'

module ActiveXML
  class GeneralError < StandardError; end
  class NotFoundError < GeneralError; end
  class CreationError < GeneralError; end
  class ParseError < GeneralError; end

  class Node
    @@elements = {}
    @@xml_time = 0

    attr_reader :init_options
    attr_reader :cache_key

    class << self
      def logger
        Rails.logger
      end

      def get_class(element_name)
        if @@elements.include? element_name
          return @@elements[element_name]
        end
        ActiveXML::Node
      end

      def handles_xml_element (*elements)
        elements.each do |elem|
          @@elements[elem] = self
        end
      end

      def runtime
        @@xml_time
      end

      def reset_runtime
        @@xml_time = 0
      end

      # transport object, gets defined according to configuration when Base is subclassed
      attr_reader :transport

      def inherited( subclass )
        # called when a subclass is defined
        # Rails.logger.debug "Initializing ActiveXML model #{subclass}"
        subclass.instance_variable_set '@default_find_parameter', @default_find_parameter
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
        # Rails.logger.debug "--> ActiveXML successfully set up"
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
            if key.nil? || value.nil?
              Rails.logger.debug "nil value given #{args.inspect}"
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

        # Rails.logger.debug "prepared find args: #{args.inspect}"
        args
      end

      def transport
        ActiveXML.backend
      end

      def calc_key( args )
        # Rails.logger.debug "Cache key for #{args.inspect}"
        name + '_' + Digest::MD5.hexdigest( '2' + args.to_s )
      end

      def find_priv(cache_time, *args )
        args = prepare_args(args)
        cache_key = calc_key( args )

        objhash = nil
        begin
          if cache_time
            fromcache = true
            objdata, params, objhash = Rails.cache.fetch(cache_key, expires_in: cache_time) do
              fromcache = false
              objdata, params = transport.find( self, *args)
              obj = new( objdata )
              [objdata, params, obj.to_hash]
            end
	    if fromcache
	      logger.debug "returning #{args.inspect} from rails cache #{cache_key}"
	    end
          else
            objdata, params = transport.find( self, *args)
          end
          obj = new( objdata ) unless obj
          obj.instance_variable_set( '@cache_key', cache_key ) if cache_key
          obj.instance_variable_set( '@init_options', params )
          obj.instance_variable_set( '@hash_cache', objhash) if objhash
          return obj
        rescue ActiveXML::Transport::NotFoundError
          Rails.logger.debug "#{name}.find( #{args.map {|a| a.inspect}.join(', ')} ) did not find anything, return nil"
          return nil
        end
      end

      def find( *args )
        find_priv(nil, *args )
      end

      def find_hashed( *args )
        ret = find( *args )
        return Xmlhash::XMLHash.new({}) unless ret
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
	free_args = prepare_args( free_args )
        key = calc_key( free_args )
	logger.debug "free_cache #{free_args.inspect} #{key}"
        Rails.cache.delete( key )
      end
    end

    # instance methods

    def initialize( data )
      @init_options = {}
      if data.kind_of? Nokogiri::XML::Node
        @data = data
      elsif data.kind_of? String
        self.raw_data = data.clone
      elsif data.kind_of? Hash
        # create new
        @init_options = data
        stub = self.class.make_stub(data)
        if stub.kind_of? String
          self.raw_data = stub
        elsif stub.kind_of? Node
          self.raw_data = stub.dump_xml
        else
          raise "make_stub should return Node or String, was #{stub.inspect}"
        end
      elsif data.kind_of? Node
        @data = data.internal_data.clone
      else
        raise 'constructor needs either XML::Node, String or Hash'
      end

      cleanup_cache
    end

    def parse(data)
      raise ParseError.new('Empty XML passed!') if data.empty?
      begin
        # puts "parse #{self.class}"
        t0 = Time.now
        @data = Nokogiri::XML::Document.parse(data.to_str.strip, nil, nil, Nokogiri::XML::ParseOptions::STRICT).root
        @@xml_time += Time.now - t0
      rescue Nokogiri::XML::SyntaxError => e
        Rails.logger.error "Error parsing XML: #{e}"
        Rails.logger.error "XML content was: #{data}"
        raise ParseError.new e.message
      end
    end
    private :parse

    def raw_data=( data )
      if data.kind_of? Nokogiri::XML::Node
        @data = data.clone
      else
        @raw_data = data.clone
        @data = nil
      end
    end

    def element_name
      _data.name
    end

    def element_name=(name)
      _data.name = name
    end

    # remember: this function does not exist!
    def _data # nodoc
      if !@data && @raw_data
        parse(@raw_data)
        # save memory
        @raw_data = nil
      end
      @data
    end
    private :_data

    def inspect
      dump_xml
    end

    def text
      # puts 'text -%s- -%s-' % [data.inner_xml, data.content]
      _data.content
    end

    def text= (what)
      _data.content = what
    end

    def each(symbol = nil)
      result = Array.new
      each_with_index(symbol) do |node, _|
        result << node
        yield node if block_given?
      end
      result
    end

    def each_with_index(symbol = nil)
      unless block_given?
        raise 'use each instead'
      end
      index = 0
      if symbol.nil?
        nodes = _data.element_children
      else
        nodes = _data.xpath(symbol.to_s)
      end
      nodes.each do |e|
        yield create_node_with_relations(e), index
        index = index + 1
      end
      nil
    end

    def find_first(symbol)
      symbol = symbol.to_s
      if @node_cache.has_key?(symbol)
        return @node_cache[symbol]
      else
        t0 = Time.now
        e = _data.xpath(symbol)
        if e.empty?
          return @node_cache[symbol] = nil
        end
        node = create_node_with_relations(e.first)
        @@xml_time += Time.now - t0
        @node_cache[symbol] = node
      end
    end

    # this function is a simplified version of XML::Simple of cpan fame
    def to_hash
      return @hash_cache if @hash_cache
      # Rails.logger.debug "to_hash #{options.inspect} #{dump_xml}"
      t0 = Time.now
      @hash_cache  = Xmlhash.parse(dump_xml)
      @@xml_time += Time.now - t0
      # Rails.logger.debug "after to_hash #{JSON.pretty_generate(@hash_cache)}"
      @hash_cache
    end

    def to_json(*a)
      to_hash.to_json(*a)
    end

    def freeze
      raise "activexml can't be frozen"
    end

    def to_s
      # raise "to_s is obsolete #{self.inspect}"
      ret = ''
      _data.children.each do |node|
        if node.text?
          ret += node.content
        end
      end
      ret
    end

    def dump_xml
      if @data.nil?
        @raw_data
      else
        _data.to_s
      end
    end

    def to_param
      if @hash_cache
        return @hash_cache['name']
      end
      _data.attributes['name'].value
    end

    def add_node(node)
      raise ArgumentError, 'argument must be a string' unless node.kind_of? String
      xmlnode = Nokogiri::XML::Document.parse(node, nil, nil, Nokogiri::XML::ParseOptions::STRICT).root
      _data.add_child(xmlnode)
      cleanup_cache
      Node.new(xmlnode)
    end

    def add_element ( element, attrs = nil )
      raise 'First argument must be an element name' if element.nil?
      el = _data.document.create_element(element)
      _data.add_child(el)
      attrs.each do |key, value|
        el[key.to_s]=value.to_s
      end if attrs.kind_of? Hash
      # you never know
      cleanup_cache
      Node.new(el)
    end

    def cleanup_cache
      @node_cache = {}
      @value_cache = {}
      @hash_cache = nil
    end

    def clone
      ret = super
      ret.cleanup_cache
      ret
    end

    def parent
      return nil unless _data.parent && _data.parent.element?
      Node.new(_data.parent)
    end

    # tests if a child element exists matching the given query.
    # query can either be an element name, an xpath, or any object
    # whose to_s method evaluates to an element name or xpath
    def has_element?( query )
      if @hash_cache && query.kind_of?(Symbol)
        return @hash_cache.has_key? query.to_s
      end
      !find_first( query ).nil?
    end

    def has_elements?
      !_data.element_children.empty?
    end

    def has_attribute?( query )
      if @hash_cache && query.kind_of?(Symbol)
        return @hash_cache.has_key? query.to_s
      end
      _data.attributes.has_key?(query.to_s)
    end

    def has_attributes?
      !_data.attribute_nodes.empty?
    end

    def delete_attribute( name )
      cleanup_cache
      _data.remove_attribute(name.to_s)
    end

    def delete_element( elem )
      if elem.kind_of? Node
        raise 'NO GOOD IDEA!' unless _data.document == elem.internal_data.document
        elem.internal_data.remove
      elsif elem.kind_of? Nokogiri::XML::Node
        raise 'this should be obsolete!!!'
      else
        s = _data.xpath(elem.to_s)
        raise 'this was supposed to return sets' unless s.kind_of? Nokogiri::XML::NodeSet
        raise 'xpath for delete did not give exactly one node!' unless s.length == 1
        s.first.remove
      end
      # you never know
      cleanup_cache
    end

    def set_attribute( name, value)
      cleanup_cache
      _data[name] = value
    end

    def create_node_with_relations( element )
      # FIXME: relation stuff should be taken into an extra module
      # puts element.name
      klass = self.class.get_class(element.name)
      node = nil
      node ||= klass.new(element)
      # Rails.logger.debug "created node: #{node.inspect}"
      node
    end

    def value( symbol )
      symbols = symbol.to_s

      if @hash_cache
        ret = @hash_cache[symbols]
        return ret if ret && ret.kind_of?(String)
      end
      return @value_cache[symbols] if @value_cache.has_key?(symbols)

      if _data.attributes.has_key?(symbols)
        return @value_cache[symbols] = _data.attributes[symbols].value
      end

      elem = _data.xpath(symbols)
      unless elem.empty?
        return @value_cache[symbols] = elem.first.inner_text
      end

      @value_cache[symbols] = nil
    end

    def find( symbol )
      symbols = symbol.to_s
      _data.xpath(symbols).each do |e|
        yield create_node_with_relations(e)
      end
    end

    def == other
      return false unless other
      _data == other.internal_data
    end

    def move_after other
      raise 'NO GOOD IDEA!' unless _data.document == other.internal_data.document
      # the naming of the API is a bit strange IMO
      _data.before(other.internal_data)
    end

    def move_before other
      raise 'NO GOOD IDEA!' unless _data.document == other.internal_data.document
      # the naming of the API is a bit strange IMO
      _data.after(other.internal_data)
    end

    def find_matching(conds)
      return self if NodeMatcher.match(self, conds) == true
      each do |c|
        ret = c.find_matching(conds)
        return ret if ret
      end
      return nil
    end

    # stay away from this
    def internal_data # nodoc
      _data
    end

    def marshal_dump
      raise "you don't want to put it in cache - never!"
    end

    def logger
      Rails.logger
    end

    def save(opt = {})
      if opt[:create]
        @raw_data = self.class.transport.create self, opt
        @data = nil
        @to_hash = nil
      else
        self.class.transport.save self, opt
      end
      free_cache
      true
    end

    def delete(opt = {})
      # Rails.logger.debug "Delete #{self.class}, opt: #{opt.inspect}"
      self.class.transport.delete self, opt
      free_cache
      true
    end

    def free_cache
      Rails.logger.debug "Free_cache -#{@cache_key}-"
      Rails.cache.delete @cache_key if @cache_key
    end
  end
end
