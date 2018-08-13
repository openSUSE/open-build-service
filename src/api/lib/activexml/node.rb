require 'nokogiri'
require 'xmlhash'

module ActiveXML
  class GeneralError < StandardError; end
  class NotFoundError < GeneralError; end
  class CreationError < GeneralError; end
  class ParseError < GeneralError; end

  class Node
    @@elements = {}

    attr_reader :init_options

    class << self
      def logger
        Rails.logger
      end

      def get_class(element_name)
        return @@elements[element_name] if @@elements.include?(element_name)
        ActiveXML::Node
      end

      # transport object, gets defined according to configuration when Base is subclassed
      attr_reader :transport

      # setup the default parameter for find calls. If the first parameter to <Model>.find is a string,
      # the value of this string is used as value f
      def default_find_parameter(sym)
        @default_find_parameter = sym
      end

      def prepare_args(args)
        if args[0].is_a?(Hash)
          hash = {}
          args[0].each do |key, value|
            if key.nil? || value.nil?
              Rails.logger.debug "nil value given #{args.inspect}"
              next
            end
            if value.is_a?(Array)
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

      def find(*args)
        args = prepare_args(args)

        begin
          objdata, params = transport.find(self, *args)
          obj ||= new(objdata)
          obj.instance_variable_set('@init_options', params)
          return obj
        rescue ActiveXML::Transport::NotFoundError
          Rails.logger.debug "#{name}.find( #{args.map(&:inspect).join(', ')} ) did not find anything, return nil"
          return
        end
      end

      def find_hashed(*args)
        ret = find(*args)
        return Xmlhash::XMLHash.new({}) unless ret
        ret.to_hash
      end
    end

    # instance methods

    def initialize(data)
      @init_options = {}
      if data.is_a?(Nokogiri::XML::Node)
        @data = data
      elsif data.is_a?(String)
        self.raw_data = data.clone
      elsif data.is_a?(Hash)
        # create new
        @init_options = data
        stub = self.class.make_stub(data)
        if stub.is_a?(String)
          self.raw_data = stub
        end
      end

      cleanup_cache
    end

    def parse(data)
      raise ParseError, 'Empty XML passed!' if data.empty?
      begin
        # puts "parse #{self.class}"
        @data = Nokogiri::XML::Document.parse(data.to_str.strip, nil, nil, Nokogiri::XML::ParseOptions::STRICT).root
      rescue Nokogiri::XML::SyntaxError => e
        Rails.logger.error "Error parsing XML: #{e}"
        Rails.logger.error "XML content was: #{data}"
        raise ParseError, e.message
      end
    end
    private :parse

    def raw_data=(data)
      if data.is_a?(Nokogiri::XML::Node)
        @data = data.clone
      else
        @raw_data = data.clone
        @data = nil
      end
    end

    def element_name
      _data.name
    end

    def _data
      if !@data && @raw_data
        parse(@raw_data)
        # save memory
        @raw_data = nil
      end
      @data
    end
    private :_data

    def text
      # puts 'text -%s- -%s-' % [data.inner_xml, data.content]
      _data.content
    end

    def text=(what)
      _data.content = what
    end

    def each(symbol = nil)
      result = []
      each_with_index(symbol) do |node, _|
        result << node
        yield node if block_given?
      end
      result
    end

    def each_with_index(symbol = nil)
      raise 'use each instead' unless block_given?
      index = 0
      if symbol.nil?
        nodes = _data.element_children
      else
        nodes = _data.xpath(symbol.to_s)
      end
      nodes.each do |e|
        yield create_node_with_relations(e), index
        index += 1
      end
      nil
    end

    def find_first(symbol)
      symbol = symbol.to_s
      return @node_cache[symbol] if @node_cache.key?(symbol)

      e = _data.xpath(symbol)
      return @node_cache[symbol] = nil if e.empty?
      node = create_node_with_relations(e.first)
      @node_cache[symbol] = node
    end

    # this function is a simplified version of XML::Simple of cpan fame
    def to_hash
      Xmlhash.parse(dump_xml)
    end

    def to_s
      # raise "to_s is obsolete #{self.inspect}"
      ret = ''
      _data.children.each do |node|
        ret += node.content if node.text?
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

    def add_node(node)
      raise ArgumentError, 'argument must be a string' unless node.is_a?(String)
      xmlnode = Nokogiri::XML::Document.parse(node, nil, nil, Nokogiri::XML::ParseOptions::STRICT).root
      _data.add_child(xmlnode)
      cleanup_cache
      Node.new(xmlnode)
    end

    def add_element(element, attrs = nil)
      raise 'First argument must be an element name' if element.nil?
      el = _data.document.create_element(element)
      _data.add_child(el)
      if attrs.is_a?(Hash)
        attrs.each do |key, value|
          el[key.to_s] = value.to_s
        end
      end
      # you never know
      cleanup_cache
      Node.new(el)
    end

    def cleanup_cache
      @node_cache = {}
      @value_cache = {}
    end

    # tests if a child element exists matching the given query.
    # query can either be an element name, an xpath, or any object
    # whose to_s method evaluates to an element name or xpath
    def has_element?(query)
      !find_first(query).nil?
    end

    def has_attribute?(query)
      _data.attributes.key?(query.to_s)
    end

    def delete_attribute(name)
      cleanup_cache
      _data.remove_attribute(name.to_s)
    end

    def set_attribute(name, value)
      cleanup_cache
      _data[name] = value
    end

    def create_node_with_relations(element)
      # FIXME: relation stuff should be taken into an extra module
      # puts element.name
      klass = self.class.get_class(element.name)
      node = nil
      node ||= klass.new(element)
      # Rails.logger.debug "created node: #{node.inspect}"
      node
    end

    def value(symbol)
      symbols = symbol.to_s

      return @value_cache[symbols] if @value_cache.key?(symbols)

      if _data.attributes.key?(symbols)
        return @value_cache[symbols] = _data.attributes[symbols].value
      end

      elem = _data.xpath(symbols)
      return @value_cache[symbols] = elem.first.inner_text unless elem.empty?

      @value_cache[symbols] = nil
    end

    def logger
      Rails.logger
    end

    def save(opt = {})
      if opt[:create]
        @raw_data = self.class.transport.create(self, opt)
        @data = nil
        @to_hash = nil
      else
        self.class.transport.save(self, opt)
      end
      true
    end
  end
end
