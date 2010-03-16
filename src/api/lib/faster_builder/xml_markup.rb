require "builder"
require "faster_builder"

# A Builder::XmlMarkup-alike which uses libxml-ruby to generate XML.
# 
# Example:
#   
#   xml = FasterBuilder::XmlMarkup.new
#   xml.instruct!
#   xml.entries(:count => 1) do
#     xml.comment!("blah blah blah")
#     xml.entry do
#       xml.id(40)
#       xml.title("Happiness")
#       xml.contents do
#         xml.cdata!("Anything does here. &&&<<><> yeah.")
#       end
#     end
#   end
#   
class FasterBuilder::XmlMarkup < BlankSlate
  
  # Creates a new FasterBuilder::XmlMarkup instance.
  def initialize(options = {})
    # TODO: add indentation support, if possible
    @options = options
    @nodes   = []
    @current_node = nil
    @encoding = XML::Encoding::UTF_8
  end
  
  def instruct!(type = :xml, attrs = {})
    raise Builder::IllegalBlockError, "Blocks are not allowed on XML instructions" if block_given?
    version  = attrs[:version]  || "1.0"
    encoding = attrs[:encoding] || XML::Encoding::UTF_8
    @doc = XML::Document.new(version)
    @encoding = @doc.encoding = encoding
  end
  
  def cdata!(data)
    (@current_node || @nodes) << XML::Node.new_cdata(data)
  end
  
  def comment!(comment)
    raise Builder::IllegalBlockError, "Blocks are not allowed on XML comments" if block_given?
    (@current_node || @nodes) << XML::Node.new_comment(comment)
  end
  
  def declare!(inst, *args, &block)
    # TODO: figure out how to generate declarations
    raise NotImplementedError, "libxml-ruby doesn't support generating declarations"
  end
  
  def tag!(element, *options, &block)
    # create a new node and intialize it
    if options.first.is_a?(Hash)
      node = XML::Node.new(element)
      content = nil
      attrs = options.first
    else
      if options.first.is_a?(Symbol)
        node = XML::Node.new("#{element}:#{options.first}")
      else
        node = XML::Node.new(element)
        content = options.first
      end
      
      attrs = options[1] || {}
    end
    
    # OPTIMIZE: figure out a way to assign these on node creation
    for attr, value in attrs
      node[attr.to_s] = value.to_s
    end
    
    (@current_node || @nodes) << node
    @current_node = node
    
    text!(content)
    
    if block
      if content
        raise ArgumentError, "XmlMarkup cannot mix a text argument with a block"
      else
        block.call(self)
      end
    end
    
    @current_node = @current_node.parent
    return self
  end
  
  def target!
    return (@doc.nil? ? @nodes : [@doc] + @nodes).map { |n| n.to_s(:encoding => @encoding) }.join("")
  end
  
  def text!(text)
    if text && @current_node
      @current_node << text
    end
  end
  alias_method :<<, :text!
  
  def method_missing(element, *options, &block)
    tag!(element, *options, &block)
  end
  
end

