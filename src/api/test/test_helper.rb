ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'action_controller/integration'
# uncomment to enable tests which currently are known to fail, but where either the test
# or the code has to be fixed
#$ENABLE_BROKEN_TEST=true

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

    def prepare_request_with_user( user, passwd )
      re = 'Basic ' + Base64.encode64( user + ':' + passwd )
      @@auth = re
    end
  
    # will provide a user without special permissions
    def prepare_request_valid_user 
      prepare_request_with_user 'tom', 'thunder'
    end
  
    def prepare_request_invalid_user
      prepare_request_with_user 'tom123', 'thunder123'
    end

    def load_backend_file(path)
      File.open(ActionController::TestCase.fixture_path + "/backend/#{path}").read()
    end

    def inject_build_job( project, package, repo, arch )
      job=IO.popen("find #{RAILS_ROOT}/tmp/backend_data/jobs/#{arch}/ -name #{project}::#{repo}::#{package}-*")
      jobfile=job.readlines.first.chomp
      jobid=""
      IO.popen("md5sum #{jobfile}|cut -d' ' -f 1") do |io|
         jobid = io.readlines.first.chomp
      end
      data = REXML::Document.new(File.new(jobfile))
      verifymd5 = data.elements["/buildinfo/verifymd5"].text
      f = File.open("#{jobfile}:status", 'w')
      f.write( "<jobstatus code=\"building\"> <jobid>#{jobid}</jobid> <workerid>simulated</workerid> <hostarch>#{arch}</hostarch> </jobstatus>" )
      f.close
      system("cd #{RAILS_ROOT}/test/fixtures/backend/binary/; exec find . -name '*#{arch}.rpm' -o -name '*src.rpm' -o -name logfile | cpio -H newc -o 2>/dev/null | curl -s -X POST -T - 'http://localhost:3201/putjob?arch=#{arch}&code=success&job=#{jobfile.gsub(/.*\//, '')}&jobid=#{jobid}' > /dev/null")
      system("echo \"#{verifymd5}  #{package}\" > #{jobfile}:dir/meta")
    end

    def wait_for_publisher
      counter = 0
      while counter < 100
        events = Dir.open("#{RAILS_ROOT}/tmp/backend_data/events/publish")
        #  3 => ".", ".." and ".ping"
        break unless events.count > 3
        sleep 0.5
        counter = counter + 1
      end
      if counter == 100
        raise "Waited 50 seconds for publisher"
      end
    end

    def run_scheduler( arch )
      perlopts="-I#{RAILS_ROOT}/../backend -I#{RAILS_ROOT}/../backend/build"
      IO.popen("cd #{RAILS_ROOT}/tmp/backend_config; exec perl #{perlopts} ./bs_sched --testmode #{arch}") do |io|
         # just for waiting until scheduler finishes
         io.each {|line| line.strip.chomp unless line.blank? }
      end
    end

    def assert_xml_tag(conds)
      node = ActiveXML::Base.new(@response.body)
      ret = node.find_matching(NodeMatcher::Conditions.new(conds))
      assert ret, "expected tag, but no tag found matching #{conds.inspect} in:\n#{node.dump_xml}" unless ret
    end

    def assert_no_xml_tag(conds)
     node = ActiveXML::Base.new(@response.body)
     ret = node.find_matching(NodeMatcher::Conditions.new(conds))
     assert !ret, "expected no tag, but found tag matching #{conds.inspect} in:\n#{node.dump_xml}" if ret
    end
  end 
end

module ActiveSupport
  class TestCase
    def assert_xml_tag(data, conds)
      node = ActiveXML::Base.new(data)
      ret = node.find_matching(NodeMatcher::Conditions.new(conds))
      assert ret, "expected tag, but no tag found matching #{conds.inspect} in:\n#{node.dump_xml}" unless ret
    end

    def assert_no_xml_tag(data, conds)
      node = ActiveXML::Base.new(data)
      ret = node.find_matching(NodeMatcher::Conditions.new(conds))
      assert !ret, "expected no tag, but found tag matching #{conds.inspect} in:\n#{node.dump_xml}" if ret
    end

  end
end

