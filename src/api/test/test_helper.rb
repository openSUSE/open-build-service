ENV['RAILS_ENV'] = 'test'

require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/app/indices/'
  add_filter '/app/models/user_ldap_strategy.rb'
end if ENV['DO_COVERAGE']

require File.expand_path('../../config/environment', __FILE__)
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
## this is the build service! 2 seconds - HAHAHA
Capybara.default_wait_time = 30

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, debug: false, timeout: 30)
end

Capybara.register_driver :rack_test do |app|
  Capybara::RackTest::Driver.new(app, headers: {'HTTP_ACCEPT' => 'text/html'})
end

Capybara.javascript_driver = :poltergeist

WebMock.disable_net_connect!(allow_localhost: true)

unless File.exists? '/proc'
  print 'ERROR: proc file system not mounted, aborting'
  exit 1
end
unless File.exists? '/dev/fd'
  print 'ERROR: /dev/fd does not exist, aborting'
  exit 1
end

# uncomment to enable tests which currently are known to fail, but where either the test
# or the code has to be fixed
#$ENABLE_BROKEN_TEST=true

def inject_build_job(project, package, repo, arch, extrabinary=nil)
  job=IO.popen("find #{Rails.root}/tmp/backend_data/jobs/#{arch}/ -name #{project}::#{repo}::#{package}-*")
  jobfile=job.readlines.first
  return unless jobfile
  jobfile.chomp!
  jobid=''
  IO.popen("md5sum #{jobfile}|cut -d' ' -f 1") do |io|
    jobid = io.readlines.first.chomp
  end
  data = REXML::Document.new(File.new(jobfile))
  verifymd5 = data.elements['/buildinfo/verifymd5'].text
  f = File.open("#{jobfile}:status", 'w')
  f.write("<jobstatus code=\"building\"> <jobid>#{jobid}</jobid> <workerid>simulated</workerid> <hostarch>#{arch}</hostarch> </jobstatus>")
  f.close
  extrabinary=" -o -name #{extrabinary}" if extrabinary
  system("cd #{Rails.root}/test/fixtures/backend/binary/; exec find . -name '*#{arch}.rpm' -o -name '*src.rpm' -o -name logfile -o -name _statistics #{extrabinary} | cpio -H newc -o 2>/dev/null | curl -s -X POST -T - 'http://localhost:3201/putjob?arch=#{arch}&code=success&job=#{jobfile.gsub(/.*\//, '')}&jobid=#{jobid}' > /dev/null")
  system("echo \"#{verifymd5}  #{package}\" > #{jobfile}:dir/meta")
end

def inject_preinstall_build_job(project, package, repo, arch)
  job=IO.popen("find #{Rails.root}/tmp/backend_data/jobs/#{arch}/ -name #{project}::#{repo}::#{package}-*")
  jobfile=job.readlines.first
  return unless File.file?("#{Rails.root}/test/fixtures/backend/binary/#{package}.info")
  return unless File.file?("#{Rails.root}/test/fixtures/backend/binary/#{package}.tar.gz")
  return unless jobfile
  jobfile.chomp!
  jobid=''
  IO.popen("md5sum #{jobfile}|cut -d' ' -f 1") do |io|
    jobid = io.readlines.first.chomp
  end
  data = REXML::Document.new(File.new(jobfile))
  verifymd5 = data.elements['/buildinfo/verifymd5'].text
  f = File.open("#{jobfile}:status", 'w')
  f.write("<jobstatus code=\"building\"> <jobid>#{jobid}</jobid> <workerid>simulated</workerid> <hostarch>#{arch}</hostarch> </jobstatus>")
  f.close
  system("cd #{Rails.root}/test/fixtures/backend/binary/; exec find . -name '#{package}.info' -o -name '#{package}.tar.gz' -o -name logfile -o -name _statistics | cpio -H newc -o 2>/dev/null | curl -s -X POST -T - 'http://localhost:3201/putjob?arch=#{arch}&code=success&job=#{jobfile.gsub(/.*\//, '')}&jobid=#{jobid}' > /dev/null")
  system("echo \"#{verifymd5}  #{package}\" > #{jobfile}:dir/meta")
  system("cat #{Rails.root}/test/fixtures/backend/binary/#{package}.info >> #{jobfile}:dir/meta")
end

module ActionDispatch
  module Integration
    class Session
      def add_auth(headers)
        headers = Hash.new if headers.nil?
        if !headers.has_key? 'HTTP_AUTHORIZATION' and IntegrationTest.basic_auth
          headers['HTTP_AUTHORIZATION'] = IntegrationTest.basic_auth
        end
        return headers
      end

      alias_method :real_process, :process

      def process(method, path, parameters, rack_env)
        CONFIG['global_write_through'] = true
        self.accept = 'text/xml,application/xml'
        real_process(method, path, parameters, add_auth(rack_env))
      end

      def raw_post(path, data, parameters = nil, rack_env = nil)
        rack_env ||= Hash.new
        rack_env['CONTENT_TYPE'] ||= 'application/octet-stream'
        rack_env['CONTENT_LENGTH'] = data.length
        rack_env['RAW_POST_DATA'] = data
        process(:post, path, parameters, add_auth(rack_env))
      end

      def raw_put(path, data, parameters = nil, rack_env = nil)
        rack_env ||= Hash.new
        rack_env['CONTENT_TYPE'] ||= 'application/octet-stream'
        rack_env['CONTENT_LENGTH'] = data.length
        rack_env['RAW_POST_DATA'] = data
        process(:put, path, parameters, add_auth(rack_env))
      end

    end
  end
end

module Webui
  class IntegrationTest < ActionDispatch::IntegrationTest
    # Make the Capybara DSL available
    include Capybara::DSL

    @@frontend = nil

    def self.start_test_api
      return if @@frontend
      if ENV['API_STARTED']
        @@frontend = :dont
        return
      end
      # avoid a race
      Suse::Backend.start_test_backend
      @@frontend = IO.popen(Rails.root.join('script', 'start_test_api').to_s)
      puts "Starting test API with pid: #{@@frontend.pid}"
      lines = []
      while true do
        line = @@frontend.gets
        unless line
          puts lines.join()
          raise RuntimeError.new('Frontend died')
        end
        break if line =~ /Test API ready/
        lines << line
      end
      puts "Test API up and running with pid: #{@@frontend.pid}"
      at_exit do
        puts "Killing test API with pid: #{@@frontend.pid}"
        Process.kill 'INT', @@frontend.pid
        begin
          Process.wait @@frontend.pid
        rescue Errno::ECHILD
          # already gone
        end
        @@frontend = nil
      end
    end

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
      login_user('tom', 'thunder', opts)
    end

    def login_Iggy(opts = {})
      login_user('Iggy', 'asdfasdf', opts)
    end

    def login_adrian(opts = {})
      login_user('adrian', 'so_alone', opts)
    end

    def login_king(opts = {})
      login_user('king', 'sunflower', opts.merge(do_assert: false))
    end

    def login_fred(opts = {})
      login_user('fred', 'geröllheimer', opts)
    end

    def login_dmayr(opts = {})
      login_user 'dmayr', '123456', opts
    end

    def logout
      @current_user = nil
      ll = page.first('#logout-link')
      ll.click if ll
    end

    def open_file(file)
      find(:css, "tr##{valid_xml_id('file-' + file)} td:first-child a").click
    end

    # ============================================================================
    #
    def edit_file(new_content)
      # new edit page does not allow comments

      savebutton = find(:css, '.buttons.save')
      page.must_have_selector('.buttons.save.inactive')

      # is it all rendered?
      page.must_have_selector('.CodeMirror-lines')

      # codemirror is not really test friendly, so just brute force it - we basically
      # want to test the load and save work flow not the codemirror library
      page.execute_script("editors[0].setValue('#{escape_javascript(new_content)}');")

      # wait for it to be active
      page.wont_have_selector('.buttons.save.inactive')
      assert !savebutton['class'].split(' ').include?('inactive')
      savebutton.click
      page.must_have_selector('.buttons.save.inactive')
      assert savebutton['class'].split(' ').include? 'inactive'

      #flash_message.must_equal "Successfully saved file #{@file}"
      #flash_message_type.must_equal :info
    end

    def current_user
      @current_user
    end

    self.use_transactional_fixtures = true
    fixtures :all

    setup do
      Capybara.current_driver = :rack_test
# crude work around - one day I will dig into why this is necessary
      Minitest::Spec.new('MINE') unless Minitest::Spec.current
      self.class.start_test_api
      #Capybara.current_driver = Capybara.javascript_driver
      @starttime = Time.now
      WebMock.disable_net_connect!(allow_localhost: true)
      CONFIG['global_write_through'] = true
    end

    def use_js
      Capybara.current_driver = Capybara.javascript_driver
    end

    teardown do
      dirpath = Rails.root.join('tmp', 'capybara')
      htmlpath = dirpath.join(self.name + '.html')
      if !passed?
        Dir.mkdir(dirpath) unless Dir.exists? dirpath
        save_page(htmlpath)
      elsif File.exists?(htmlpath)
        File.unlink(htmlpath)
      end

      Capybara.reset!
      Rails.cache.clear
      WebMock.reset!
      ActiveRecord::Base.clear_active_connections!

      unless run_in_transaction?
        DatabaseCleaner.clean_with :deletion
      end

      #puts "#{self.__name__} took #{Time.now - @starttime}"
    end

    def fill_autocomplete(field, options = {})
      fill_in field, with: options[:with]

      page.execute_script %Q{ $('##{field}').trigger('focus') }
      page.execute_script %Q{ $('##{field}').trigger('keydown') }

      page.must_have_selector('ul.ui-autocomplete li.ui-menu-item a')
      ret = []
      all('ul.ui-autocomplete li.ui-menu-item a').each do |l|
        ret << l.text
      end
      ret.must_include options[:select]
      page.execute_script %Q{ select_from_autocomplete('#{options[:select]}') }
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
      return ret
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
      find(:id, 'del_dialog').must_have_text 'Delete Confirmation'
      find_button('Ok').click
      find('#flash-messages').must_have_text "Package '#{package}' was removed successfully"
    end

  end
end

module ActionDispatch
  class IntegrationTest

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
      return @@auth
    end

    def basic_auth
      return @@auth
    end

    def prepare_request_with_user(user, passwd)
      re = 'Basic ' + Base64.encode64(user + ':' + passwd)
      @@auth = re
    end

    # will provide a user without special permissions
    def prepare_request_valid_user
      prepare_request_with_user 'tom', 'thunder'
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

    def wait_for_publisher
      Rails.logger.debug 'Wait for publisher'
      counter = 0
      while counter < 100
        events = Dir.open(Rails.root.join('tmp/backend_data/events/publish'))
        #  3 => ".", ".." and ".ping"
        break unless events.count > 3
        sleep 0.5
        counter = counter + 1
      end
      if counter == 100
        raise 'Waited 50 seconds for publisher'
      end
    end

    def wait_for_scheduler_start
      Suse::Backend.wait_for_scheduler_start
    end

    def run_scheduler(arch)
      Rails.logger.debug "RUN_SCHEDULER #{arch}"
      perlopts="-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
      IO.popen("cd #{Rails.root}/tmp/backend_config; exec perl #{perlopts} ./bs_sched --testmode #{arch}") do |io|
        # just for waiting until scheduler finishes
        io.each { |line| line.strip.chomp unless line.blank? }
      end
    end

    def login_king
      prepare_request_with_user 'king', 'sunflower'
    end

    def login_Iggy
      prepare_request_with_user 'Iggy', 'asdfasdf'
    end

    def login_adrian
      prepare_request_with_user 'adrian', 'so_alone'
    end

    def login_fred
      prepare_request_with_user 'fred', 'geröllheimer'
    end

    def login_tom
      prepare_request_with_user 'tom', 'thunder'
    end

    def login_dmayr
      prepare_request_with_user 'dmayr', '123456'
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

