require "net/http"
require "tempfile"

class ParameterError < Exception
end

class TestContext

  attr_writer :user, :password, :show_xmlbody, :request_filter

  def initialize requests
    @host_aliases = Hash.new

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
    "\033[1m#{str}\033[0m"
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
    puts magenta( "  UNSUPPORTED" )
    @unsupported += 1
  end

  def failed
    puts red( "  FAILED" )
    @failed += 1
  end

  def passed
    puts green( "  PASSED" )
    @passed += 1
  end

  def skipped
#    puts magenta( "  SKIPPED" )
    @skipped += 1
  end

  def error str = nil
    error_str = "  ERROR"
    if ( str )
      error_str += ": " + str
    end
    puts red( error_str )
    @error += 1
  end

  def alias_host old, new
    @host_aliases[ old ] = new
  end

  def request arg
    @tested += 1

    if ( @request_filter && arg !~ /#{@request_filter}/ )
      skipped
      return nil
    end

    puts bold( "REQUEST: " + arg )

    request = @requests.find { |r| r.to_s == arg }

    if ( !request )
      STDERR.puts "  Request not defined"
      return nil
    end

    xml_results = request.all_children XmlResult
    if ( !xml_results.empty? )
      xml_result = xml_results[0]
      puts "  XMLRESULT: " + xml_result.name
    end
    
    puts "  host: '#{request.host}'"

    host = request.host.to_s
    if ( !host || host.empty? )
      error "No host defined"
      return nil
    end

    if @host_aliases[ host ]
      host = @host_aliases[ host ]
    end

    puts "  aliased host: #{host}"

    begin
      path = substitute_parameters request
    rescue ParameterError
      error
      return nil
    end

    puts "  Path: " + path

    splitted_host = host.split( ":" )
    
    host_name = splitted_host[0]
    host_port = splitted_host[1]

    puts "  Host name: #{host_name} port: #{host_port}"

    if ( request.verb == "GET" )
      req = Net::HTTP::Get.new( path )
      req.basic_auth( @user, @password )
      response = Net::HTTP.start( host_name, host_port ) do |http|
        http.request( req )
      end
      if ( response.is_a? Net::HTTPRedirection )
        location = URI.parse response["location"]
        puts "  Redirected to #{location}"
        req = Net::HTTP::Get.new( location.path )
        req.basic_auth( @user, @password )
        response = Net::HTTP.start( location.host, location.port ) do |http|
          http.request( req )
        end
      end
    elsif( request.verb == "POST" )
      req = Net::HTTP::Post.new( path )
      req.basic_auth( @user, @password )
      response = Net::HTTP.start( host_name, host_port ) do |http|
        http.request( req, "" )
      end
    elsif( request.verb == "PUT" )
      if ( !@data_body )
        error "No body data defined for PUT"
        return nil
      end
      puts "  PUT"
      req = Net::HTTP::Put.new( path )
      req.basic_auth( @user, @password )
      response = Net::HTTP.start( host_name, host_port ) do |http|
        http.request( req, @data_body )
      end
    else
      STDERR.puts "  Test of method '#{request.verb}' not supported yet."
      unsupported
      return nil
    end

    if ( response )
      puts "  return code: #{response.code}"
      if ( xml_result && @show_xmlbody )
        puts response.body
      end

      if ( response.is_a? Net::HTTPSuccess )
        if ( xml_result )
          if ( xml_result.schema )
            schema_file = xml_result.schema
          else
            schema_file = xml_result.name + ".xsd"
          end
          if ( validate_xml response.body, schema_file )
            puts "  Response validates against schema '#{schema_file}'"
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
    path = request.path
    
    request.parameters.each do |parameter|
      p = parameter.name
      arg = eval( "@arg_#{parameter.name}" )
      if ( !arg )
        puts "  Can't substitute parameter '#{p}'. " +
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

    out = `/usr/bin/xmllint --noout --schema #{schema_file} #{tmp_path} 2>&1`
    if $?.exitstatus > 0
      STDERR.puts "xmllint return value: #{$?.exitstatus}"
      STDERR.puts out
      return false
    end
    return true
  end

  def print_summary
    undefined = @tested - @unsupported - @failed - @passed - @error - @skipped
  
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
