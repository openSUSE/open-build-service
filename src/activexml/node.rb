require 'nokogiri'
require 'json'
require 'xmlhash'

# adding a function to the ruby hash
class Hash
  def elements(name)
    unless name.kind_of? String
      raise ArgumentError, "expected string"
    end
    sub = self[name]
    return [] unless sub
    unless sub.kind_of? Array
      if block_given?
        yield sub
	return
      else
        return [sub]
      end
    end
    return sub unless block_given? 
    sub.each do |n|
      yield n
    end
  end

  def get(name)
    sub = self[name]
    return sub if sub
    return {}
  end

  def value(name)
    return self[name.to_s]
  end

  def has_element?(name)
    return self.has_key? name.to_s
  end

  def has_attribute?(name) 
    return self.has_key? name.to_s
  end

  def method_missing( symbol, *args, &block )
    if args.size > 0 || !block.nil?
      raise RuntimeError, "das geht zuweit #{symbol.inspect}(#{args.inspect})"
    end
    
    ActiveXML::Config.logger.debug "method_missing -#{symbol}- #{block.inspect}"
    return self[symbol.to_s]
  end
end

module ActiveXML

  class LibXMLNode

    @@elements = {}
    @@xml_time = 0

    class << self

      def get_class(element_name)
        # FIXME: lines below don't work with relations. the related model has to
        # be pulled in when the relation is defined
        #
        # axbase_subclasses = ActiveXML::Base.subclasses.map {|sc| sc.downcase}
        # if axbase_subclasses.include?( element_name )

        if @@elements.include? element_name
          return @@elements[element_name]
        end
        return ActiveXML::LibXMLNode
      end

      #creates an empty xml document
      # FIXME: works only for projects/packages, or by overwriting it in the model definition
      # FIXME: could get info somehow from schema, as soon as schema evaluation is built in
      def make_stub(opt)
        #logger.debug "--> creating stub element for #{self.name}, arguments: #{opt.inspect}"
        if opt.nil?
          raise CreationError, "Tried to create document without opt parameter"
        end
        root_tag_name = self.name.downcase
        doc = ActiveXML::Base.new("<#{root_tag_name}/>")
        doc.set_attribute('name', opt[:name])
        doc.set_attribute('created', opt[:created_at]) if opt[:created_at]
        doc.set_attribute('updated', opt[:updated_at]) if opt[:updated_at]
        doc.add_element 'title'
        doc.add_element 'description'
        doc
      end

      def logger
        ActiveXML::Config.logger
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

    end

    #instance methods

    def initialize( data )
      if data.kind_of? Nokogiri::XML::Node
        @data = data
      elsif data.kind_of? String
        self.raw_data = data.clone
      elsif data.kind_of? Hash
        #create new
        stub = self.class.make_stub(data)
        if stub.kind_of? String
          self.raw_data = stub
        elsif stub.kind_of? LibXMLNode
          self.raw_data = stub.dump_xml
        else
          raise "make_stub should return LibXMLNode or String, was #{stub.inspect}"
        end
      elsif _data.kind_of? LibXMLNode
        @data = data.internal_data.clone
      else
        raise "constructor needs either XML::Node, String or Hash"
      end

      cleanup_cache
    end

    def parse(data)
      raise ParseError.new('Empty XML passed!') if data.empty?
      begin
	#puts "parse #{self.class}"
        t0 = Time.now
        @data = Nokogiri::XML::Document.parse(data.to_str.strip, nil, nil, Nokogiri::XML::ParseOptions::STRICT).root
        @@xml_time += Time.now - t0
      rescue Nokogiri::XML::SyntaxError => e
        logger.error "Error parsing XML: #{e}"
        logger.error "XML content was: #{data}"
        raise ParseError.new e.message
      end
    end
    private :parse

    def raw_data=( data )
      if data.kind_of? Nokogiri::XML::Node
        @data = data.clone
      else
        if ActiveXML::Config.lazy_evaluation
          @raw_data = data.clone
          @data = nil
        else
          parse(data)
        end
      end
    end

    def element_name
      _data.name
    end

    def element_name=(name)
      _data.name = name
    end

    # remember: this function does not exist!
    def _data #nodoc
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
      #puts 'text -%s- -%s-' % [data.inner_xml, data.content]
      _data.content
    end

    def text= (what)
      _data.content = what.fast_xs
    end

    def each(symbol = nil)
      result = Array.new
      each_with_index(symbol) do |node, index|
        result << node
        yield node if block_given?
      end
      return result
    end

    def each_with_index(symbol = nil)
      unless block_given?
        raise "use each instead"
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

    def logger
      self.class.logger
    end

    # this function is a simplified version of XML::Simple of cpan fame
    def to_hash
      return @hash_cache if @hash_cache
      #logger.debug "to_hash #{options.inspect} #{dump_xml}"
      t0 = Time.now
      x = Benchmark.measure { @hash_cache  = Xmlhash.parse(dump_xml) }
      @@xml_time += Time.now - t0
      #logger.debug "after to_hash #{JSON.pretty_generate(@hash_cache)}"
      #puts "to_hash #{self.class} #{x}"
      @hash_cache
    end
    
    def to_json(*a)
      to_hash.to_json(*a)
    end

    def freeze
      raise "activexml can't be frozen"
    end

    def to_s
      #raise "to_s is obsolete #{self.inspect}"
      ret = ''
      _data.children.each do |node|
        if node.text?
          ret += node.content
        end
      end
      ret
    end

    def marshal_dump
      raise "you don't want to put it in cache - never!"
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
         return @hash_cache["name"]
      end
      _data.attributes['name'].value
    end

    def add_node(node)
      raise ArgumentError, "argument must be a string" unless node.kind_of? String
      xmlnode = Nokogiri::XML::Document.parse(node, nil, nil, Nokogiri::XML::ParseOptions::STRICT).root
      _data.add_child(xmlnode)
      cleanup_cache
      xmlnode
    end

    def add_element ( element, attrs=nil )
      raise "First argument must be an element name" if element.nil?
      el = _data.document.create_element(element)
      _data.add_child(el)
      attrs.each do |key, value|
        el[key.to_s]=value.to_s
      end if attrs.kind_of? Hash
      # you never know
      cleanup_cache
      LibXMLNode.new(el)
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
      return nil unless _data.parent and _data.parent.element?
      LibXMLNode.new(_data.parent)
    end

    #tests if a child element exists matching the given query.
    #query can either be an element name, an xpath, or any object
    #whose to_s method evaluates to an element name or xpath
    def has_element?( query )
      if @hash_cache && query.kind_of?(Symbol)
        return @hash_cache.has_key? query.to_s
      end
      !find_first( query ).nil?
    end

    def has_elements?
      return !_data.element_children.empty?
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
      if elem.kind_of? LibXMLNode
        raise "NO GOOD IDEA!" unless _data.document == elem.internal_data.document
        elem.internal_data.remove
      elsif elem.kind_of? Nokogiri::XML::Node
        raise "this should be obsolete!!!"
        elem.remove
      else
        s = _data.xpath(elem.to_s)
	raise "this was supposed to return sets" unless s.kind_of? Nokogiri::XML::NodeSet
        raise "xpath for delete did not give exactly one node!" unless s.length == 1
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
      #FIXME: relation stuff should be taken into an extra module
      #puts element.name
      klass = self.class.get_class(element.name)
      opt = {}
      node = nil
      node ||= klass.new(element)
      #logger.debug "created node: #{node.inspect}"
      return node
    end

    def value( symbol ) 
      symbols = symbol.to_s

      if @hash_cache 
	  ret = @hash_cache[symbols]
	  return ret if ret && ret.kind_of?(String)
      end
      return @value_cache[symbols] if @value_cache.has_key?(symbols)

      return nil unless _data

      if _data.attributes.has_key?(symbols)
        return @value_cache[symbols] = _data.attributes[symbols].value
      end

      elem = _data.xpath(symbols)
      unless elem.empty?
        return @value_cache[symbols] = elem.first.inner_text
      end

      return @value_cache[symbols] = nil
    end

    def find( symbol, &block ) 
       symbols = symbol.to_s
       _data.xpath(symbols).each do |e|
         block.call(create_node_with_relations(e))
       end 
    end

    def method_missing( symbol, *args, &block )
      #puts "called method: #{symbol}(#{args.map do |a| a.inspect end.join ', '})"

      symbols = symbol.to_s
      if( symbols =~ /^each_(.*)$/ )
        elem = $1
        return [] if not has_element? elem
        result = Array.new
        _data.xpath(elem).each do |e|
          result << node = create_node_with_relations(e)
          block.call(node) if block
        end
        return result
      end

      return nil unless _data

      if _data.attributes[symbols]
        return _data.attributes[symbols].value
      end

#      puts "method_missing bouncing to find_first #{symbols}"
      find_first(symbols)
    end

    def == other
       return false unless other
       _data == other.internal_data
    end

    def move_after other
      raise "NO GOOD IDEA!" unless _data.document == other.internal_data.document	    
      # the naming of the API is a bit strange IMO
      _data.before(other.internal_data)
    end

    def move_before other
      raise "NO GOOD IDEA!" unless _data.document == other.internal_data.document
      # the naming of the API is a bit strange IMO
      _data.after(other.internal_data)
    end
    
    def find_matching(conds)
      return self if NodeMatcher.match(self, conds) == true
      self.each do |c|
        ret = c.find_matching(conds)
        return ret if ret
      end
      return nil
    end

    # stay away from this
    def internal_data #nodoc
      _data
    end
    protected :internal_data
  end

  class XMLNode < LibXMLNode
  end

end
