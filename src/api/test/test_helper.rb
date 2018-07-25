ENV['origin_RAILS_ENV'] = ENV['RAILS_ENV']

ENV['RAILS_ENV'] = 'test'

require 'simplecov'
require 'builder'
require 'minitest/reporters'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

if ENV['DO_COVERAGE']
  ENV['CODECOV_FLAG'] = ENV['CIRCLE_STAGE']
  SimpleCov.start 'rails' do
    # NOTE: Keep filters in sync with spec/support/coverage.rb
    add_filter '/app/indices/'
    add_filter '/lib/templates/'
    add_filter '/lib/memory_debugger.rb'
    add_filter '/lib/memory_dumper.rb'
    merge_timeout 3600
  end

  SimpleCov.at_exit do
    puts 'Coverage done'
    SimpleCov.result.format!
  end
end

require File.expand_path('../../config/environment', __FILE__)
require_relative 'test_consistency_helper'

require 'rails/test_help'

require 'minitest/unit'

require 'webmock/minitest'

require_relative 'activexml_matcher'
require_relative '../lib/obsapi/test_sphinx'

require 'test/unit/assertions'
require 'mocha/setup'

require 'capybara/rails'
Capybara.default_max_wait_time = 6

Capybara.register_driver :rack_test do |app|
  Capybara::RackTest::Driver.new(app, headers: { 'HTTP_ACCEPT' => 'text/html' })
end

WebMock.disable_net_connect!(allow_localhost: true)

unless File.exist? '/proc'
  print 'ERROR: proc file system not mounted, aborting'
  exit 1
end
unless File.exist? '/dev/fd'
  print 'ERROR: /dev/fd does not exist, aborting'
  exit 1
end

# uncomment to enable tests which currently are known to fail, but where either the test
# or the code has to be fixed
# @ENABLE_BROKEN_TEST=true

def backend_config
  backend_dir_suffix = ''
  if ENV['origin_RAILS_ENV'] == 'development'
    backend_dir_suffix = '_development'
  end
  "#{ENV['OBS_BACKEND_TEMP']}/config#{backend_dir_suffix}"
end

def backend_data
  backend_dir_suffix = ''
  if ENV['origin_RAILS_ENV'] == 'development'
    backend_dir_suffix = '_development'
  end
  "#{ENV['OBS_BACKEND_TEMP']}/data#{backend_dir_suffix}"
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
  # rubocop:disable Metrics/LineLength
  system("cd #{Rails.root}/test/fixtures/backend/binary/; exec find . -name '*#{arch}.rpm' -o -name '*src.rpm' -o -name logfile -o -name _statistics #{extrabinary} | cpio -H newc -o 2>/dev/null | curl -s -X POST -T - 'http://localhost:3201/putjob?arch=#{arch}&code=success&job=#{jobfile.gsub(/.*\//, '')}&jobid=#{jobid}' > /dev/null")
  # rubocop:enable Metrics/LineLength
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

class ActionDispatch::IntegrationTest
  # usually we do only test at the end of all tests to not slow down too much.
  # but for debugging or for deep testing the check can be run after each test case
  def after_teardown
    super
    # begin
    #   # something else is going wrong in some random test and you do not know where?
    #   # add the specific test for it here:
    #   # login_king
    #   # get "/source/home:Iggy/TestPack/_link"
    #   # assert_response 404
    #
    #   # simple test that the objects itself or the same in backend and api.
    #   # it does not check the content (eg. repository list in project meta)
    #   compare_project_and_package_lists
    # rescue MiniTest::Assertion => e
    #   puts "Backend became out of sync in #{name}"
    #   puts e.inspect
    #   exit
    # end
  end
end

module ActionDispatch
  module Integration
    class Session
      def add_auth(headers)
        headers = {} if headers.nil?
        if !headers.key?('HTTP_AUTHORIZATION') && IntegrationTest.basic_auth
          headers['HTTP_AUTHORIZATION'] = IntegrationTest.basic_auth
        end

        headers
      end

      alias_method :real_process, :process

      def process(http_method, path, params: nil, headers: nil, env: nil, xhr: false, as: nil)
        CONFIG['global_write_through'] = true
        # Hack to pass the APIMatcher (config/routes.rb) without
        # explicitly setting format: xml
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
      # no idea why calling it twice would help
      WebMock.disable_net_connect!(allow_localhost: true)
      visit session_new_path
      fill_in 'Username', with: user
      fill_in 'Password', with: password
      click_button 'Log In'

      visit opts[:to] if opts[:to]

      @current_user = user
      if opts[:do_assert] != false
        assert_match %r{^#{user}( |$)}, find(:css, '#link-to-user-home').text
      end
      # login into API to ease test cases
      prepare_request_with_user(user, password)
    end

    def current_user
      @current_user
    end

    self.use_transactional_tests = true
    fixtures :all

    setup do
      Capybara.current_driver = :rack_test
      # crude work around - one day I will dig into why this is necessary
      Minitest::Spec.new('MINE') unless Minitest::Spec.current
      Backend::Test.start
      @starttime = Time.now
      WebMock.disable_net_connect!(allow_localhost: true)
      CONFIG['global_write_through'] = true
    end

    teardown do
      dirpath = Rails.root.join('tmp', 'capybara')
      htmlpath = dirpath.join(name + '.html')
      if !passed?
        Dir.mkdir(dirpath) unless Dir.exist? dirpath
        save_page(htmlpath)
      elsif File.exist?(htmlpath)
        File.unlink(htmlpath)
      end

      Capybara.reset!
      Rails.cache.clear
      WebMock.reset!
      ActiveRecord::Base.clear_active_connections!
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
      User.current = nil
      @@auth = nil
    end

    def self.basic_auth
      @@auth
    end

    def basic_auth
      @@auth
    end

    def prepare_request_with_user(user, passwd)
      @@auth = 'Basic ' + Base64.encode64(user + ':' + passwd)
    end

    # will provide a user without special permissions
    def prepare_request_valid_user
      prepare_request_with_user 'tom', 'buildservice'
    end

    def prepare_request_invalid_user
      prepare_request_with_user 'tom123', 'thunder123'
    end

    def load_fixture(path)
      File.open(File.join(ActionController::TestCase.fixture_path, path)).read
    end

    def load_backend_file(path)
      load_fixture("backend/#{path}")
    end

    def assert_xml_tag(conds)
      node = ActiveXML::Node.new(@response.body)
      ret = node.find_matching(NodeMatcher::Conditions.new(conds))
      raise MiniTest::Assertion, "expected tag, but no tag found matching #{conds.inspect} in:\n#{node.dump_xml}" unless ret
    end

    def assert_no_xml_tag(conds)
      node = ActiveXML::Node.new(@response.body)
      ret = node.find_matching(NodeMatcher::Conditions.new(conds))
      raise MiniTest::Assertion, "expected no tag, but found tag matching #{conds.inspect} in:\n#{node.dump_xml}" if ret
    end

    # useful to fix our test cases
    def url_for(hash)
      raise ArgumentError, 'we need a hash here' unless hash.is_a? Hash
      raise ArgumentError, 'we need a :controller' unless hash.key?(:controller)
      raise ArgumentError, 'we need a :action' unless hash.key?(:action)
      super(hash)
    end

    def login_king
      prepare_request_with_user 'king', 'sunflower'
    end

    def login_Iggy
      prepare_request_with_user 'Iggy', 'buildservice'
    end

    def login_adrian
      prepare_request_with_user 'adrian', 'buildservice'
    end

    def login_adrian_downloader
      prepare_request_with_user 'adrian_downloader', 'buildservice'
    end

    def login_fred
      prepare_request_with_user 'fred', 'buildservice'
    end

    def login_tom
      prepare_request_with_user 'tom', 'buildservice'
    end

    def login_dmayr
      prepare_request_with_user 'dmayr', 'buildservice'
    end
  end
end

class ActiveSupport::TestCase
  set_fixture_class events: Event::Base
  set_fixture_class history_elements: HistoryElement::Base

  def assert_xml_tag(data, conds)
    node = ActiveXML::Node.new(data)
    ret = node.find_matching(NodeMatcher::Conditions.new(conds))
    assert ret, "expected tag, but no tag found matching #{conds.inspect} in:\n#{node.dump_xml}" unless ret
  end

  def assert_no_xml_tag(data, conds)
    node = ActiveXML::Node.new(data)
    ret = node.find_matching(NodeMatcher::Conditions.new(conds))
    assert !ret, "expected no tag, but found tag matching #{conds.inspect} in:\n#{node.dump_xml}" if ret
  end

  def load_fixture(path)
    File.open(File.join(ActionController::TestCase.fixture_path, path)).read
  end

  def load_backend_file(path)
    load_fixture("backend/#{path}")
  end

  def teardown
    Rails.cache.clear
  end
end
