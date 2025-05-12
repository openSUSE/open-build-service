ENV['origin_RAILS_ENV'] = ENV.fetch('RAILS_ENV', nil)

ENV['RAILS_ENV'] = 'test'
ENV['RUNNING_MINITEST'] = '1'

require 'simplecov'
require 'builder'
require 'minitest/reporters'

Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)

require File.expand_path('../config/environment', __dir__)
require_relative 'test_consistency_helper'

require 'rails/test_help'

require 'minitest/unit'

require 'minitest/spec'

require 'webmock/minitest'

require_relative 'node_matcher'

require 'test/unit/assertions'
require 'mocha/minitest'

require 'capybara/rails'
Capybara.default_max_wait_time = 6
# Attempt to click the associated label element if a checkbox/radio button are non-visible (This is especially useful for Bootstrap custom controls)
Capybara.automatic_label_click = true

Capybara.register_driver :rack_test do |app|
  Capybara::RackTest::Driver.new(app, headers: { 'HTTP_ACCEPT' => 'text/html' })
end

if ENV['RUNNING_MINITEST_WITH_DOCKER']
  WebMock.disable_net_connect!(allow: 'backend:5352')
else
  WebMock.disable_net_connect!(allow_localhost: true)
end

unless File.exist?('/proc')
  print 'ERROR: proc file system not mounted, aborting'
  exit 1
end
unless File.exist?('/dev/fd')
  print 'ERROR: /dev/fd does not exist, aborting'
  exit 1
end

# uncomment to enable tests which currently are known to fail, but where either the test
# or the code has to be fixed
# @ENABLE_BROKEN_TEST=true

def backend_config
  backend_dir_suffix = ''
  backend_dir_suffix = '_development' if ENV.fetch('origin_RAILS_ENV', nil) == 'development'
  "#{ENV.fetch('OBS_BACKEND_TEMP', nil)}/config#{backend_dir_suffix}"
end

def backend_data
  backend_dir_suffix = ''
  backend_dir_suffix = '_development' if ENV.fetch('origin_RAILS_ENV', nil) == 'development'
  "#{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data#{backend_dir_suffix}"
end

def inject_build_job(project, package, repo, arch, extrabinary = nil)
  job = IO.popen("find #{backend_data}/jobs/#{arch}/ -name #{project}::#{repo}::#{package}-*")
  jobfile = job.readlines.first
  return if project == 'BrokenPublishing'
  raise unless jobfile

  jobfile.chomp!
  jobid = ''
  IO.popen("md5sum #{jobfile}|cut -d' ' -f 1") do |io|
    jobid = io.readlines.first.chomp
  end
  data = REXML::Document.new(File.new(jobfile))
  verifymd5 = data.elements['/buildinfo/verifymd5'].text
  f = File.open("#{jobfile}:status", 'w')

  output = '<jobstatus code="building">' \
           "<jobid>#{jobid}</jobid>" \
           '<starttime>0</starttime>' \
           '<workerid>simulated</workerid>' \
           "<hostarch>#{arch}</hostarch>" \
           '</jobstatus>'

  f.write(output)
  f.close
  extrabinary = " -o -name #{extrabinary}" if extrabinary
  system("cd #{Rails.root}/test/fixtures/backend/binary/; exec find . -name '*#{arch}.rpm' -o -name '*src.rpm' -o -name logfile -o -name _statistics #{extrabinary} | " \
         'cpio -H newc -o 2>/dev/null | ' \
         "curl -s -X POST -T - 'http://localhost:3201/putjob?arch=#{arch}&code=succeeded&job=#{jobfile.gsub(%r{.*/}, '')}&jobid=#{jobid}' > /dev/null")
  system("echo \"#{verifymd5}  #{package}\" > #{jobfile}:dir/meta")
end

module Minitest
  def self.__run(reporter, options)
    # there is no way to avoid the randomization of used suites, so we overload this method.
    suites = Runnable.runnables # .shuffle <- disabled here
    parallel, serial = suites.partition { |s| s.test_order == :parallel }

    serial.map { |suite| suite.run reporter, options } +
      parallel.map { |suite| suite.run reporter, options }
  end

  # we should fix this first ... unfortunatly there seems to be no way to repeat the last order
  # to find out what went wrong and to validate it :(
  def self.sort_order
    :sorted
  end
end

# class ActionDispatch::IntegrationTest
#   # usually we do only test at the end of all tests to not slow down too much.
#   # but for debugging or for deep testing the check can be run after each test case
#   def after_teardown
#     begin
#       # something else is going wrong in some random test and you do not know where?
#       # add the specific test for it here:
#       # login_king
#       # get "/source/home:Iggy/TestPack/_link"
#       # assert_response 404
#
#       # simple test that the objects itself or the same in backend and api.
#       # it does not check the content (eg. repository list in project meta)
#       compare_project_and_package_lists
#     rescue MiniTest::Assertion => e
#       puts "Backend became out of sync in #{name}"
#       puts e.inspect
#       exit
#     end
#   end
# end

module ActionDispatch
  module Integration
    class Session
      def add_auth(headers)
        headers = {} if headers.nil?
        headers['HTTP_AUTHORIZATION'] = IntegrationTest.basic_auth if !headers.key?('HTTP_AUTHORIZATION') && IntegrationTest.basic_auth

        headers
      end

      alias real_process process

      def process(http_method, path, params: nil, headers: nil, env: nil, xhr: false, as: nil)
        CONFIG['global_write_through'] = true
        # Hack to pass the RoutesHelper::APIMatcher without explicitly setting format: xml
        self.accept = 'text/xml,application/xml'

        real_process(http_method, path, params: params, headers: add_auth(headers), env: env, xhr: xhr, as: as)
      end

      def raw_post(path, data)
        rack_env = {}
        rack_env['CONTENT_TYPE'] ||= 'application/octet-stream'
        rack_env['CONTENT_LENGTH'] = data.length
        rack_env['RAW_POST_DATA'] = data
        process(:post, path, env: add_auth(rack_env))
      end

      def raw_put(path, data)
        rack_env ||= {}
        rack_env['CONTENT_TYPE'] ||= 'application/octet-stream'
        rack_env['CONTENT_LENGTH'] = data.length
        rack_env['RAW_POST_DATA'] = data
        process(:put, path, env: add_auth(rack_env))
      end
    end
  end
end

module Webui
  class IntegrationTest < ActionDispatch::IntegrationTest
    # Make the Capybara DSL available
    include Capybara::DSL

    def login_king(opts = {})
      user = 'king'
      password = 'sunflower'
      opts[:do_assert] = false
      visit new_session_path
      within('#loginform') do
        fill_in 'username', with: user
        fill_in 'password', with: password
        click_button 'Log In'
      end

      visit opts[:to] if opts[:to]

      @current_user = user
      assert_match(/^#{user}( |$)/, find_by_id('link-to-user-home').text) if opts[:do_assert] != false
      # login into API to ease test cases
      prepare_request_with_user(user, password)
    end

    attr_reader :current_user

    self.use_transactional_tests = true
    fixtures :all

    setup do
      Capybara.current_driver = :rack_test
      # crude work around - one day I will dig into why this is necessary
      Minitest::Spec.new('MINE') unless Minitest::Spec.current
      Backend::Test.start
      @starttime = Time.now
      if ENV['RUNNING_MINITEST_WITH_DOCKER']
        WebMock.disable_net_connect!(allow: 'backend:5352')
      else
        WebMock.disable_net_connect!(allow_localhost: true)
      end
      CONFIG['global_write_through'] = true
    end

    teardown do
      dirpath = Rails.root.join('tmp', 'capybara')
      htmlpath = dirpath.join("#{name}.html")
      if passed?
        FileUtils.rm_f(htmlpath)
      else
        FileUtils.mkdir_p(dirpath)
        save_page(htmlpath) # rubocop:disable Lint/Debugger
      end

      Capybara.reset!
      Rails.cache.clear
      WebMock.reset!
      ActiveRecord::Base.connection_handler.clear_active_connections!
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Backend::Test::Tasks

    def teardown
      Rails.cache.clear
      reset_auth
      WebMock.reset!
    end

    @@auth = nil

    def reset_auth
      User.session = nil
      @@auth = nil
    end

    def self.basic_auth
      @@auth
    end

    def basic_auth
      @@auth
    end

    def prepare_request_with_user(user, passwd)
      basic_auth_credentials = "#{user}:#{passwd}"
      @@auth = "Basic #{Base64.encode64(basic_auth_credentials)}"
    end

    # will provide a user without special permissions
    def prepare_request_valid_user
      prepare_request_with_user('tom', 'buildservice')
    end

    def prepare_request_invalid_user
      prepare_request_with_user('tom123', 'thunder123')
    end

    def load_fixture(path)
      File.read(File.join(ActionController::TestCase.fixture_paths, path))
    end

    def load_backend_file(path)
      load_fixture("backend/#{path}")
    end

    def check_xml_tag(data, conds)
      xml = Nokogiri::XML(data, &:strict)
      NodeMatcher.new(conds).find_matching(xml.root)
    end

    def assert_xml_tag(conds)
      ret = check_xml_tag(@response.body, conds)
      raise MiniTest::Assertion, "expected tag, but no tag found matching #{conds.inspect} in:\n#{@response.body}" unless ret
    end

    def assert_no_xml_tag(conds)
      ret = check_xml_tag(@response.body, conds)
      raise MiniTest::Assertion, "expected no tag, but found tag matching #{conds.inspect} in:\n#{@response.body}" if ret
    end

    # useful to fix our test cases
    def url_for(hash)
      raise ArgumentError, 'we need a hash here' unless hash.is_a?(Hash)
      raise ArgumentError, 'we need a :controller' unless hash.key?(:controller)
      raise ArgumentError, 'we need a :action' unless hash.key?(:action)

      super
    end

    def login_king
      prepare_request_with_user('king', 'sunflower')
    end

    def login_Iggy
      prepare_request_with_user('Iggy', 'buildservice')
    end

    def login_adrian
      prepare_request_with_user('adrian', 'buildservice')
    end

    def login_adrian_downloader
      prepare_request_with_user('adrian_downloader', 'buildservice')
    end

    def login_fred
      prepare_request_with_user('fred', 'buildservice')
    end

    def login_tom
      prepare_request_with_user('tom', 'buildservice')
    end

    def login_dmayr
      prepare_request_with_user('dmayr', 'buildservice')
    end
  end
end

class ActiveSupport::TestCase
  set_fixture_class events: Event::Base
  set_fixture_class history_elements: HistoryElement::Base

  def check_xml_tag(data, conds)
    xml = Nokogiri::XML(data, &:strict)
    NodeMatcher.new(conds).find_matching(xml.root)
  end

  def assert_xml_tag(data, conds)
    ret = check_xml_tag(data, conds)
    assert ret, "expected tag, but no tag found matching #{conds.inspect} in:\n#{data}" unless ret
  end

  def assert_no_xml_tag(data, conds)
    ret = check_xml_tag(data, conds)
    assert_not ret, "expected no tag, but found tag matching #{conds.inspect} in:\n#{data}" if ret
  end

  def load_fixture(path)
    File.read(File.join(ActionController::TestCase.fixture_paths, path))
  end

  def load_backend_file(path)
    load_fixture("backend/#{path}")
  end

  def teardown
    Rails.cache.clear
  end
end
