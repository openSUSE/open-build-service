ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'action_controller/integration'

module ActionController
  module Integration #:nodoc:
    class Session
      def add_auth(headers)
        headers = Hash.new if headers.nil?
        if !headers.has_key? "AUTHORIZATION" and IntegrationTest.basic_auth
          headers["AUTHORIZATION"] = IntegrationTest.basic_auth
        end
        return headers
      end

      def get(path, parameters = nil, headers = nil)
        process :get, path, parameters, add_auth(headers)
      end
      def post(path, parameters = nil, headers = nil)
        process :post, path, parameters, add_auth(headers)
      end
      def put(path, parameters = nil, headers = nil)
        process :put, path, parameters, add_auth(headers)
      end
      def delete(path, parameters = nil, headers = nil)
        process :delete, path, parameters, add_auth(headers)
      end

    end
  end

  class IntegrationTest

    @@auth = nil

    def self.reset_auth
      @@auth = nil
    end

    def self.basic_auth
      return @@auth
    end

    def prepare_request_with_user( request, user, passwd )
      re = 'Basic ' + Base64.encode64( user + ':' + passwd )
      @@auth = re
    end
  
    # will provide a user without special permissions
    def prepare_request_valid_user ( request )
      prepare_request_with_user request, 'tom', 'thunder'
    end
  
    def prepare_request_invalid_user( request )
      prepare_request_with_user request, 'tom123', 'thunder123'
    end

    def load_backend_file(path)
      File.open(ActionController::TestCase.fixture_path + "/backend/#{path}").read()
    end

  end 
end

module Test
  module Unit
    class AutoRunner
      alias :old_run :run

      def run
	Thread.abort_on_exception = true

        srcsrv_out = nil
	logger = RAILS_DEFAULT_LOGGER
	FileUtils.rm_rf("#{RAILS_ROOT}/tmp/backend_data")
        FileUtils.rm_rf("#{RAILS_ROOT}/tmp/backend_config")
	
	FileUtils.mkdir "#{RAILS_ROOT}/tmp/backend_config"
	file = File.open("#{RAILS_ROOT}/tmp/backend_config/BSConfig.pm", "w")
	File.open("../backend/BSConfig.pm.template") do |template|
	  template.readlines.each do |line|
	    line.gsub!(/(our \$bsuser)/, '#\1')
	    line.gsub!(/(our \$bsgroup)/, '#\1')
	    line.gsub!(/our \$bsdir = .*/, "our $bsdir = '#{RAILS_ROOT}/tmp/backend_data';")
	    line.gsub!(/:5352/, ":#{SOURCE_PORT}")
	    line.gsub!(/:5252/, ":3201") # not yet used
	    file.print line
	  end
	end
	file.close

        srcsrv = Thread.new do
	  FileUtils.symlink("#{RAILS_ROOT}/../backend/bs_srcserver", "#{RAILS_ROOT}/tmp/backend_config/bs_srcserver")
          Dir.chdir("#{RAILS_ROOT}/tmp/backend_config")
          srcsrv_out = IO.popen("exec perl -I#{RAILS_ROOT}/../backend -I#{RAILS_ROOT}/../backend/build ./bs_srcserver 2>&1")
	  puts "popened #{Process.pid} -> #{srcsrv_out.pid}"
          Process.setpgid srcsrv_out.pid, 0
          while srcsrv_out
            begin
              line = srcsrv_out.gets
              logger.debug line.strip unless line.blank?
            rescue IOError
              break
            end
          end
        end

        while true
          begin
            Net::HTTP.start(SOURCE_HOST, SOURCE_PORT) {|http| http.get('/') }
          rescue Errno::ECONNREFUSED
	    #puts "waiting"
            sleep 1
            next
          end
          break
        end

        ret = old_run
        puts "kill #{srcsrv_out.pid}"
        Process.kill "INT", -srcsrv_out.pid
        srcsrv_out.close
        srcsrv_out = nil
        srcsrv.join
        FileUtils.rm_rf("#{RAILS_ROOT}/tmp/backend_data")
        FileUtils.rm_rf("#{RAILS_ROOT}/tmp/backend_config")
        return ret
      end
    end
  end
end

