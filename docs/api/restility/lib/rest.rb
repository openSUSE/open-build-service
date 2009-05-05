#!/usr/bin/ruby

class XmlFile

  @@include_dir = ""

  def XmlFile.include_dir= dir
    if !dir
      dir = ""
    end
    @@include_dir = dir
  end
  
  def XmlFile.exist? file_name
    exists? file_name
  end
  
  def XmlFile.exists? file_name
    find_file file_name
  end
  
  def XmlFile.copy file_name, output_dir
    dir_name = File.dirname( file_name )

    if ( dir_name =~ /^\// )
      puts STDERR, "Absolute file names aren't allowed as XML file names."
        + " (#{dir_name})";
      return
    end

    if ( dir_name )
      output_dir += "/" + dir_name
    end
    
    if ( dir_name && !dir_name.empty? && !File.exist?( dir_name ) )
      `mkdir -p #{output_dir}`
      if ( $? != 0 )
        puts STDERR, "Unable to create directory '#{dir_name}'"
      end
    end
    
    File.copy( find_file( file_name ), output_dir )
    
  end
  
  def XmlFile.find_file file_name
    if ( File.exists? file_name )
      return file_name
    end
 
    if ( !@@include_dir.empty? )
      file_name = @@include_dir + "/" + file_name
      if ( File.exists? file_name )
        return file_name
      end
    end
    
    return nil
  end
  
end

class Node
  attr_accessor :parent, :level, :name
  attr_reader :children

  def initialize n = nil
    @name = n
    @children = Array.new
    @level = 0
  end

  def add_child c
    @children.push c
    c.parent = self
    c.level = @level + 1
  end

  def print printer
    printer.do_print self
  end
  
  def print_children printer
    if ( @children )
      @children.each do |child|
        child.print printer
      end
    end
  end

  def root?
    return !parent
  end

  def root
    if parent
      return parent.root
    end
    return self
  end

  def to_s
    @name
  end

  def all_children type
    @result = Array.new
    @children.each do |child|
      if ( child.class == type )
        @result.push child
      end
      @result.concat( child.all_children( type ) )
    end
    @result
  end

end

class Section < Node
end

class Request < Node
  
  attr_accessor :verb, :path, :id

  @@id = 0

  def initialize
    @id = @@id;
    @@id += 1
    super()
  end
  
  def to_s
    p = @path.gsub(/<([^>]*?)\??>=/, "\\1=")
    @verb + " " + p
  end

  def parameters
    result = Array.new
    @path.scan( /[^=]<(.*?)(\??)>/ ) do |p|
      node = self
      found = false
      optional = $2.empty? ? false : true
      while( node && !found )
        node.children.each do |c|
          if ( c.is_a?( Parameter ) && c.name == $1 )
            c.optional = optional
            result.push c
            found = true
            break
          end
        end
        node = node.parent
      end
      if ( !found )
        n = Parameter.new( $1 )
        n.optional = optional
        result.push n
      end
    end
    result
  end

  def host
    node = self
    while( node )
      node.children.each do |c|
        if c.is_a? Host
          return c
        end
      end
      node = node.parent
    end
    nil
  end
  
end

class Text < Node

  attr_accessor :text

  def initialize
    @text = Array.new
    super()
  end

  def to_s
    @text.join("\n")
  end

  def append t
    @text.push t
  end

end

class Parameter < Node

  attr_accessor :description, :optional

  def initialize n = nil
    @optional = false
    super
  end

  def to_s
    s = @name.to_s
    s += " (optional)" if @optional
    if ( !@description || @description.empty? )
      s
    else
      s + " - " + @description
    end
  end

end

class Xml < Node
  attr_accessor :schema
end

class Body < Node
end

class Result < Node
end

class XmlBody < Xml
end

class XmlResult < Xml
end

class Host < Node
end

class Contents < Node
end

class Version < Node
end

class Document < Section

  def initialize
    super
    self.name = "DOCUMENT"
  end

  def parse_args
    sections = Hash.new

    sections[ 0 ] = self

    @section = nil

    while line = gets
      if ( line =~ /^\s+(\S.*)$/ )
        if ( !@text )
          @text = Text.new
        end
        @text.append $1
      else
        if ( @text && @current )
          @current.add_child @text
        end
        @text = nil
      end

      if ( line =~ /^(=+) (.*)/ )
        level = $1.size
        title = $2

        @section = Section.new title
        @current = @section

        parent = sections[ level - 1 ]
        parent.add_child @section
        sections[ level ] = @section

      elsif ( line =~ /^(GET|PUT|POST|DELETE) (.*)/ )
        @request = Request.new
        @current = @request

        @request.verb = $1
        @request.path = $2

        @section.add_child( @request )

      elsif ( line =~ /^<(.*)>: (.*)/ )
        parameter = Parameter.new

        parameter.name = $1
        parameter.description = $2

        @current.add_child( parameter )

      elsif ( line =~ /^Host: (.*)/ )
        host = Host.new $1
        @current.add_child( host )

      elsif ( line =~ /^Body: (.*)/ )
        body = Body.new $1
        @current.add_child( body )

      elsif ( line =~ /^Result: (.*)/ )
        result = Result.new $1
        @current.add_child( result )

      elsif ( line =~ /^XmlBody: (.*)/ )
        body = XmlBody.new $1
        @current.add_child( body )

      elsif ( line =~ /^XmlResult: (.*) +(.*)/ )
        result = XmlResult.new $1
        result.schema = $2
        @current.add_child( result )

      elsif ( line =~ /^XmlResult: (.*)/ )
        result = XmlResult.new $1
        @current.add_child( result )

      elsif ( line =~ /^Contents/ )
        @current.add_child( Contents.new )

      elsif ( line =~ /^Version: (.*)/ )
        version = Version.new $1
        @current.add_child( version )

      end

    end
  end

end


class Printer

  def initialize
    @missing = Hash.new
  end

  def print node
    do_prepare
    do_print node
    do_finish
  end

  def print_document printer
    print_section printer
  end

  def do_print node
    method = "print_" + node.class.to_s.downcase
    send method, node
  end
  
  def do_prepare
  end
  
  def do_finish
  end

  def method_missing symbol, *args
    if ( !@missing[ symbol ] )
      @missing[ symbol ] = true
      STDERR.puts "Warning: #{self.class} doesn't support '#{symbol}'."
    end
  end

end

class TextPrinter < Printer

  def indent node
    node.level.times do
      printf "  "
    end
  end

  def print_section section
    indent section
    puts "SECTION " + section.to_s
    section.print_children self
  end

  def print_request request
    indent request
    puts "Request: " + request.to_s
    host = request.host
    if ( host )
      indent host
      puts "  HOST: " + host.name
    end
    request.parameters.each do |p|
      indent request
      puts "  PARAMETER: #{p.to_s}"
    end
    request.print_children self
  end

  def print_text text
    text.text.each do |t|
      indent text
      puts t
    end
  end

  def print_parameter parameter
    indent parameter
    puts "PARAMETER_DEF: " + parameter.name + " - " + parameter.description
  end

  def print_host host
    indent host
    puts "HOST_DEF: " + host.name
  end

  def print_result result
    indent result
    puts "Result: " + result.name
  end

  def print_xmlresult result
    indent result
    printf "XmlResult: " + result.name
    if ( result.schema )
      printf " (Schema: #{result.schema})"
    end
    printf "\n"
  end

  def print_body body
    indent body
    puts "Body: " + body.name
  end

end


class OutlinePrinter < Printer
  def print node
    node.level.times do
      printf "  "
    end
    puts "#{node.level} #{node.class}"
    node.print_children self
  end

  def print_section node
    print node
  end
end
