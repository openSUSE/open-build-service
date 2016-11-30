ENV['origin_RAILS_ENV'] = ENV['RAILS_ENV']

ENV['RAILS_ENV'] = 'test'

require 'simplecov'
require 'coveralls'
require "minitest/reporters"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

if ENV['DO_COVERAGE']
  Coveralls.wear_merged!('rails')

  SimpleCov.start 'rails' do
    add_filter '/app/indices/'
    add_filter '/app/models/user_ldap_strategy.rb'
    add_filter '/lib/templates/'
    merge_timeout 3600
    formatter Coveralls::SimpleCov::Formatter
  end

  SimpleCov.at_exit do
    puts "Coverage done"
    SimpleCov.result.format!
  end
end

require File.expand_path('../../config/environment', __FILE__)
require_relative 'test_consistency_helper'

require 'rails/test_help'

require 'minitest/unit'

require 'webmock/minitest'

require 'opensuse/backend'

require_relative 'activexml_matcher'
require_relative '../lib/obsapi/test_sphinx'

require 'test/unit/assertions'
require 'mocha/setup'
require 'capybara/poltergeist'

require 'capybara/rails'
Capybara.default_max_wait_time = 6

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, debug: false, timeout: 30)
end

Capybara.register_driver :rack_test do |app|
  Capybara::RackTest::Driver.new(app, headers: {'HTTP_ACCEPT' => 'text/html'})
end

Capybara.javascript_driver = :poltergeist

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
# $ENABLE_BROKEN_TEST=true

def backend_config
  backend_dir_suffix = ""
  if ENV['origin_RAILS_ENV'] == 'development'
    backend_dir_suffix = "_development"
  end
  "#{Rails.root}/tmp/backend_config#{backend_dir_suffix}"
end

def backend_data
  backend_dir_suffix = ""
  if ENV['origin_RAILS_ENV'] == 'development'
    backend_dir_suffix = "_development"
  end
  "#{Rails.root}/tmp/backend_data#{backend_dir_suffix}"
end

def inject_build_job(project, package, repo, arch, extrabinary = nil)
  job=IO.popen("find #{backend_data}/jobs/#{arch}/ -name #{project}::#{repo}::#{package}-*")
  jobfile=job.readlines.first
  return if project == "BrokenPublishing"
  raise unless jobfile
  jobfile.chomp!
  jobid=''
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
  extrabinary=" -o -name #{extrabinary}" if extrabinary
  # rubocop:disable Metrics/LineLength
  system("cd #{Rails.root}/test/fixtures/backend/binary/; exec find . -name '*#{arch}.rpm' -o -name '*src.rpm' -o -name logfile -o -name _statistics #{extrabinary} | cpio -H newc -o 2>/dev/null | curl -s -X POST -T - 'http://localhost:3201/putjob?arch=#{arch}&code=success&job=#{jobfile.gsub(/.*\//, '')}&jobid=#{jobid}' > /dev/null")
  # rubocop:enable Metrics/LineLength
  system("echo \"#{verifymd5}  #{package}\" > #{jobfile}:dir/meta")
end

module Minitest
  def self.__run reporter, options
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
        if !headers.has_key?("HTTP_AUTHORIZATION") && IntegrationTest.basic_auth
          headers["HTTP_AUTHORIZATION"] = IntegrationTest.basic_auth
        end
        headers
      end

      alias real_process process_with_kwargs

      def process_with_kwargs(http_method, path, *args)
        CONFIG['global_write_through'] = true
        # Hack to pass the APIMatcher (config/routes.rb) without
        # explicitly setting format: xml
        self.accept = 'text/xml,application/xml'
        if kwarg_request?(args)
          parameters = args[0]
          parameters[:headers] = add_auth(parameters[:headers])
          real_process(http_method, path, parameters)
        else
          real_process(http_method, path, params: args[0], headers: add_auth(args[1]))
        end
      end

      def raw_post(path, data, parameters = {}, rack_env = nil)
        rack_env ||= {}
        rack_env['CONTENT_TYPE'] ||= 'application/octet-stream'
        rack_env['CONTENT_LENGTH'] = data.length
        rack_env['RAW_POST_DATA'] = data
        process_with_kwargs(:post, path, parameters, add_auth(rack_env))
      end

      def raw_put(path, data, parameters = {}, rack_env = nil)
        rack_env ||= {}
        rack_env['CONTENT_TYPE'] ||= 'application/octet-stream'
        rack_env['CONTENT_LENGTH'] = data.length
        rack_env['RAW_POST_DATA'] = data
        process_with_kwargs(:put, path, parameters, add_auth(rack_env))
      end
    end
  end
end

module Webui
  class IntegrationTest < ActionDispatch::IntegrationTest
    # Make the Capybara DSL available
    include Capybara::DSL

    def login_user(user, password, opts = {})
      # no idea why calling it twice would help
      WebMock.disable_net_connect!(allow_localhost: true)
      visit user_login_path
      fill_in 'Username', with: user
      fill_in 'Password', with: password
      click_button 'Log In'

      visit opts[:to] if opts[:to]

      @current_user = user
      if opts[:do_assert] != false
        assert_match %r{^#{user}( |$)}, find('#link-to-user-home').text
      end
      # login into API to ease test cases
      prepare_request_with_user(user, password)
    end

    # will provide a user without special permissions
    def login_tom(opts = {})
      login_user('tom', 'buildservice', opts)
    end

    def login_Iggy(opts = {})
      login_user('Iggy', 'buildservice', opts)
    end

    def login_adrian(opts = {})
      login_user('adrian', 'buildservice', opts)
    end

    def login_king(opts = {})
      login_user('king', 'sunflower', opts.merge(do_assert: false))
    end

    def login_fred(opts = {})
      login_user('fred', 'buildservice', opts)
    end

    def login_dmayr(opts = {})
      login_user 'dmayr', 'buildservice', opts
    end

    def logout
      @current_user = nil
      ll = page.first('#logout-link')
      ll.click if ll
    end

    def current_user
      @current_user
    end

    def self.load_fixture(path)
      File.open(File.join(ActionController::TestCase.fixture_path, path)).read()
    end

    def self.load_backend_file(path)
      load_fixture("backend/#{path}")
    end

    self.use_transactional_tests = true
    fixtures :all

    setup do
      Capybara.current_driver = :rack_test
# crude work around - one day I will dig into why this is necessary
      Minitest::Spec.new('MINE') unless Minitest::Spec.current
      Suse::Backend.start_test_backend
      # Capybara.current_driver = Capybara.javascript_driver
      @starttime = Time.now
      WebMock.disable_net_connect!(allow_localhost: true)
      CONFIG['global_write_through'] = true
    end

    def use_js
      Capybara.current_driver = Capybara.javascript_driver
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

      unless run_in_transaction?
        DatabaseCleaner.clean_with :deletion
      end

      # puts "#{self.__name__} took #{Time.now - @starttime}"
    end

    def fill_autocomplete(field, options = {})
      fill_in field, with: options[:with]

      page.execute_script "$('##{field}').trigger('focus')"
      page.execute_script "$('##{field}').trigger('keydown')"

      page.must_have_selector('ul.ui-autocomplete li.ui-menu-item a')
      ret = []
      all('ul.ui-autocomplete li.ui-menu-item a').each do |l|
        ret << l.text
      end
      ret.must_include options[:select]
      page.execute_script "select_from_autocomplete('#{options[:select]}')"
      ret
    end

    # ============================================================================
    # Checks if a flash message is displayed on screen
    #
    def flash_message_appeared?
      flash_message_type != nil
    end

    # ============================================================================
    # Returns the text of the flash message currenlty on screen
    # @note Doesn't fail if no message is on screen. Returns empty string instead.
    # @return [String]
    #
    def flash_message
      results = all(:css, 'div#flash-messages p')
      if results.empty?
        return 'none'
      end
      if results.count > 1
        texts = results.map { |r| r.text }
        raise "One flash expected, but we had #{texts.inspect}"
      end
      results.first.text
    end

    # ============================================================================
    # Returns the text of the flash messages currenlty on screen
    # @note Doesn't fail if no message is on screen. Returns empty list instead.
    # @return [array]
    #
    def flash_messages
      results = all(:css, 'div#flash-messages p')
      ret = []
      results.each { |r| ret << r.text }
      ret
    end

    # ============================================================================
    # Returns the type of the flash message currenlty on screen
    # @note Does not fail if no message is on screen! Returns nil instead!
    # @return [:info, :alert]
    #
    def flash_message_type
      result = first(:css, 'div#flash-messages span')
      return nil unless result
      return :info if result['class'].include? 'info'
      return :alert if result['class'].include? 'alert'
    end

    # helper function for teardown
    def delete_package project, package
      visit package_show_path(package: package, project: project)
      find(:id, 'delete-package').click
      find(:id, 'del_dialog').must_have_text 'Do you really want to delete this package?'
      find_button('Ok').click
      find('#flash-messages').must_have_text "Package was successfully removed."
    end

    def valid_xml_id(rawid)
      Webui::WebuiController.new.valid_xml_id(rawid)
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include TestBackendTasks

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
      File.open(File.join(ActionController::TestCase.fixture_path, path)).read()
    end

    def load_backend_file(path)
      load_fixture("backend/#{path}")
    end

    def assert_xml_tag(conds)
      node = ActiveXML::Node.new(@response.body)
      ret = node.find_matching(NodeMatcher::Conditions.new(conds))
      raise MiniTest::Assertion.new("expected tag, but no tag found matching #{conds.inspect} in:\n#{node.dump_xml}") unless ret
    end

    def assert_no_xml_tag(conds)
      node = ActiveXML::Node.new(@response.body)
      ret = node.find_matching(NodeMatcher::Conditions.new(conds))
      raise MiniTest::Assertion.new("expected no tag, but found tag matching #{conds.inspect} in:\n#{node.dump_xml}") if ret
    end

    # useful to fix our test cases
    def url_for(hash)
      raise ArgumentError.new('we need a hash here') unless hash.kind_of? Hash
      raise ArgumentError.new('we need a :controller') unless hash.has_key?(:controller)
      raise ArgumentError.new('we need a :action') unless hash.has_key?(:action)
      super(hash)
    end

    def wait_for_scheduler_start
      Suse::Backend.wait_for_scheduler_start
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
    File.open(File.join(ActionController::TestCase.fixture_path, path)).read()
  end

  def load_backend_file(path)
    load_fixture("backend/#{path}")
  end

  def teardown
    Rails.cache.clear
  end
end
