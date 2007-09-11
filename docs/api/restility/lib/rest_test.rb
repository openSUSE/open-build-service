require "net/https"
require "tempfile"

class ParameterError < Exception
end

class TestContext

  attr_writer :show_xmlbody, :request_filter, :show_passed, :output_html

  def initialize requests
    @host_aliases = Hash.new

    @output = ""

    @requests = requests
    start
  end

  def start
    @tested = 0
    @unsupported = 0
    @failed = 0
    @passed = 0
    @error = 0
    @skipped = 0
  end

  def bold str
    if @output_html
      str.gsub! /</, "&lt;"
      str.gsub! />/, "&gt;"
      "<b>#{str}</b>"
    else
      "\033[1m#{str}\033[0m"
    end
  end
  
  def red str
    bold str
#    "\E[31m#{str}\E[30m"
  end
  
  def green str
    bold str
  end

  def magenta str
    bold str
  end

  def get_binding
    return binding()
  end

  def unsupported
    out magenta( "  UNSUPPORTED" )
    @unsupported += 1
    out_flush
  end

  def failed
    out red( "  FAILED" )
    @failed += 1
    out_flush
  end

  def passed
    out green( "  PASSED" )
    @passed += 1
    if ( @show_passed )
      out_flush
    else
      out_clear
    end
  end

  def skipped
#    out magenta( "  SKIPPED" )
    @skipped += 1
    out_flush
  end

  def error str = nil
    error_str = "  ERROR"
    if ( str )
      error_str += ": " + str
    end
    out red( error_str )
    @error += 1
    out_flush
  end

  def alias_host old, new
    @host_aliases[ old ] = new
  end

  def out str
    @output += str + "\n";
  end
  
  def out_clear
    @output = ""
  end
  
  def out_flush
    print @output
    out_clear
  end

  def request arg, return_code = nil, xml_check_wanted = true
    @tested += 1

    if ( @request_filter && arg !~ /#{@request_filter}/ )
      skipped
      return nil
    end

    out bold( "REQUEST: " + arg )

    request = @requests.find { |r|
      r.to_s == arg
    }

    if ( !request )
      STDERR.puts "  Request not defined"
      return nil
    end

    xml_bodies = request.all_children XmlBody
    if ( !xml_bodies.empty? )
      xml_body = xml_bodies[0]
      out "  XMLBODY: " + xml_body.name
    end
    
    xml_results = request.all_children XmlResult
    if ( !xml_results.empty? )
      xml_result = xml_results[0]
      out "  XMLRESULT: " + xml_result.name
    end

    out "  host: '#{request.host}'"

    host = request.host.to_s
    if ( !host || host.empty? )
      error "No host defined"
      return nil
    end

    if @host_aliases[ host ]
      host = @host_aliases[ host ]
    end

    out "  aliased host: #{host}"

    begin
      path = substitute_parameters request
    rescue ParameterError
      error
      return nil
    end

    out "  Path: " + path

    splitted_host = host.split( ":" )
    
    host_name = splitted_host[0]
    host_port = splitted_host[1]

    out "  Host name: #{host_name} port: #{host_port}"

    if ( request.verb == "GET" )
      req = Net::HTTP::Get.new( path )
      if ( true||@user )
        req.basic_auth( @user, @password )
      end
      response = Net::HTTP.start( host_name, host_port ) do |http|
        http.request( req )
      end
      if ( response.is_a? Net::HTTPRedirection )
        location = URI.parse response["location"]
        out "  Redirected to #{location}, scheme is #{location.scheme}"
        http = Net::HTTP.new( location.host, location.port )
        if location.scheme == "https"
          http.use_ssl = true
        end
        http.start do |http|
          req = Net::HTTP::Get.new( location.path )

          if ( @user )
            out "  setting user #{@user}"
            req.basic_auth( @user, @password )
          end
        
          out "  calling #{location.host}, #{location.port}"
          response = http.request( req )
        end
      end
    elsif( request.verb == "POST" )
      req = Net::HTTP::Post.new( path )
      if ( @user )
        req.basic_auth( @user, @password )
      end
      response = Net::HTTP.start( host_name, host_port ) do |http|
        http.request( req, "" )
      end
    elsif( request.verb == "PUT" )
      if ( !@data_body )
        error "No body data defined for PUT"
        return nil
      end
      
      if ( xml_body && @show_xmlbody )
        out "Request body:"
        out @data_body
      end

      req = Net::HTTP::Put.new( path )
      if ( @user )
        req.basic_auth( @user, @password )
      end
      response = Net::HTTP.start( host_name, host_port ) do |http|
        http.request( req, @data_body )
      end
    else
      STDERR.puts "  Test of method '#{request.verb}' not supported yet."
      unsupported
      return nil
    end

    if ( response )
      out "  return code: #{response.code}"
      if ( xml_result && @show_xmlbody )
        out "Response body:"
        out response.body
      end

      if ( ( return_code && response.code == return_code.to_s ) ||
           ( response.is_a? Net::HTTPSuccess ) )
        if ( xml_check_wanted && xml_result )
          if ( xml_result.schema )
            schema_file = xml_result.schema
          else
            schema_file = xml_result.name + ".xsd"
          end
          if ( validate_xml response.body, schema_file )
            out "  Response validates against schema '#{schema_file}'"
            passed
          else
            failed
          end
        else
          passed
        end
      else
        failed
      end
    end

    response

  end

  def substitute_parameters request
    path = request.path.clone
    
    request.parameters.each do |parameter|
      p = parameter.name
      arg = eval( "@arg_#{parameter.name}" )
      if ( !arg )
        out "  Can't substitute parameter '#{p}'. " +
          "No variable @arg_#{p} defined."
        raise ParameterError
      end
      path.gsub! /<#{p}>/, arg
    end
    
    path
  end

  def validate_xml xml, schema_file
    tmp = Tempfile.new('rest_test_validator')
    tmp.print xml
    tmp_path = tmp.path
    tmp.close

    found_schema_file = XmlFile.find_file schema_file

    if ( !found_schema_file )
      out "  Unable to find schema file '#{schema_file}'"
      return false
    end

    cmd = "/usr/bin/xmllint --noout --schema #{found_schema_file} #{tmp_path} 2>&1"
#    puts "CMD: " + cmd
    output = `#{cmd}`
    if $?.exitstatus > 0
      out "xmllint return value: #{$?.exitstatus}"
      out output
      return false
    end
    return true
  end

  def print_summary
    undefined = @tested - @unsupported - @failed - @passed - @error - @skipped
  
    puts "#tester passed #{@passed}"
    puts "#tester failed #{@failed}"
    puts "#tester error #{@error}"
    puts "#tester skipped #{@unsupported + @skipped + undefined}"

    puts

    puts "Total #{@tested} tests"
    puts "  #{@passed} passed"
    puts "  #{@failed} failed"
    if ( @unsupported > 0 )
      puts "  #{@unsupported} unsupported"
    end
    if ( @error > 0 )
      puts "  #{@error} errors"
    end
    if ( @skipped > 0 )
      puts "  #{@skipped} skipped"
    end
    if ( undefined > 0 )
      puts "  #{undefined} undefined"
    end

  end

end

class TestRunner

  attr_reader :context

  def initialize requests
    @context = TestContext.new requests
  end

  def run testfile
    File.open testfile do |file|
      eval( file.read, @context.get_binding )
    end

    @context.print_summary
  end

end
