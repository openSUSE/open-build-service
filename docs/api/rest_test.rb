require "net/http"
require "tempfile"

class TestContext

  attr_writer :user, :password, :show_body

  def initialize requests
    @requests = requests
    start
  end

  def start
    @tested = 0
    @unsupported = 0
    @failed = 0
    @passed = 0
  end

  def bold str
    "\033[1m#{str}\033[0m"
  end
  
  def red str
    bold str
#    "\E[31m#{str}\E[30m"
  end
  
  def green str
    str
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

  def request arg
    puts bold( "REQUEST: " + arg )

    @tested += 1

    request = @requests.find { |r| r.to_s == arg }

    if ( !request )
      STDERR.puts "  Request not defined"
      return
    end

    xml_results = request.all_children XmlResult
    if ( !xml_results.empty? )
      xml_result = xml_results[0]
      puts "  XMLRESULT: " + xml_result.name
    end
    
    puts "  host: '#{request.host}'"

    host = request.host.to_s
    if ( !host || host.empty? )
      STDERR.puts "  No host defined."
      return
    end

    if ( request.verb == "GET" )
      req = Net::HTTP::Get.new( request.path )
      req.basic_auth( @user, @password )
      response = Net::HTTP.start( host ) do |http|
        http.request( req )
      end
    else
      STDERR.puts "  Test of method '#{request.verb}' not supported yet."
      unsupported
      return
    end

    parameters = request.parameters
    if ( !parameters.empty? )
      STDERR.puts "  Parameter substitution not supported yet."
      unsupported
      return
    end

    if ( response )
      puts "  return code: #{response.code}"
      if ( @show_body )
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
    error = @tested - @unsupported - @failed - @passed
  
    puts "Total #{@tested} tests"
    puts "  #{@passed} passed"
    puts "  #{@failed} failed"
    if ( @unsupported )
      puts "  #{@unsupported} unsupported"
    end
    if ( error )
      puts "  #{error} errors"
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
      eval file.read, @context.get_binding
    end

    @context.print_summary
  end

end
