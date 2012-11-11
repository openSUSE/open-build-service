# ==============================================================================
# Contains functionality to define and group tests into test-suites. The tests
# of any TestCase can be extracted into an array by TestCase#suite. A separate
# TestCase instance object gets created for each test which can be later run by
# TestCase#run. 
# @see TestRunner
#
class TestCase

  attr_reader :name, :status, :message, :screenshot, 
              :time_started, :time_completed, :stderr, :stdout
  attr_writer :status

  class LimitsHaveBeenExpanded < Exception; end

  # ============================================================================
  # Returns all tests defined in this test case.
  # @return [Array] array of symbols
  def self.tests
    []
  end
  
  
  # ============================================================================
  # Defines a new test for this test case.
  # @param [Symbol] name the name of the new test
  # @param [Block] body the body of the test passed as a block
  #
  # @example Define a test foobar()
  #   test :foobar do
  #     ...
  #   end
  #
  def self.test name, &body
    if tests.include? name
      raise ArgumentError, "test '#{name.to_s}' is already defined in #{self.to_s}!"
    end
    unless name.instance_of? Symbol
      raise ArgumentError, "Test name must be a symbol!"
    end
    # override self#tests method to include the newly added test.
    define_method name, body
    tests_string = "["
    tests.each { |t| tests_string += ":#{t.to_s}," }
    tests_string += ":#{name.to_s}]"
    eval "def self.tests; #{tests_string} end"
  end


  # ============================================================================
  # Creates test objects for each test defined in this class and returns them as
  # an array.
  # @return [Array] array of TestCase objects.
  #
  def self.suite
    tests.collect { |t| self.new t } 
  end
  
  def log(status, msg)
    if status == :error
      @stderr += msg + "\n"
      puts msg
    else
      @stdout += msg + "\n"
    end 
  end

  # ============================================================================
  # Creates a new instance of the given test case which has the purpose of 
  # running one particular test.
  # @note Raises ArgumentError if the test_name wasn't 
  #   found in the TestCase class
  # @param [Symbol] test_name the name of the target test.
  #
  def initialize test_name
    unless self.class.tests.include? test_name 
      raise ArgumentError,
        "Invalid test name! No test '#{test_name.to_s}' defined in #{self.class.to_s}!"
    end
    @name   = test_name
    @status = :ready
    @stdout = ''
    @stderr = ''
  end
  
  
  # ============================================================================
  # Runs the loaded test. Stores various data that can be later accessed like
  # start/end time, screenshots, pass/fail result, details and so on.
  #
  def run
    @status = :running
    @time_started = Time.now
    begin
      send @name
    rescue SkipTestError => error
      @status = :skip
      @message = "Skipped!"
    rescue LimitsHaveBeenExpanded
      @status = :rescheduled
      @message = "Rescheduled"
    rescue Exception => error
      @status = :fail
      @message = error.inspect + "\n"
      error.backtrace.each { |line| @message += line + "\n" }
      @screenshot = $data[:report_path] + "#{@name}.png"
      #sleep 300
      begin
        $page.save_screenshot @screenshot
        $page.save_source_html $data[:report_path] + "#{@name}.source.html"
      rescue Exception => error
        # keep original error 
      end
    else
      @status = :pass
      @message = "Cheers!"
    end
    @time_completed = Time.now
  end


  # ============================================================================
  # The current test depends on the tests passed to this method. If any of them
  # have failed or haven't been run yet the test would be skipped.
  # @param [*Symbol] tests one or more tests to depend on represented by symbols
  #
  # @example test bar() depends on test bar()
  #   test :bar do
  #     depend_on :foo
  #     ...
  #   end
  #
  def depend_on *tests
    if TestRunner.check_dependencies(tests)
       raise LimitsHaveBeenExpanded
    end
    tests.each do |test| 
      if TestRunner.status_of?(test) != :pass
        skip
      end
    end
  end


  # ============================================================================
  # Skips the current test by raising a SkipTestError.
  #
  def skip
    raise SkipTestError
  end


  # ============================================================================
  # Checks if the previous test have passed.
  #
  def previous_test_passed?
    TestRunner.status_of?(TestRunner.previous_test) == :pass
  end


  # ============================================================================
  # Checks if the previous test have failed.
  #
  def previous_test_failed?
    TestRunner.status_of?(TestRunner.previous_test) == :fail
  end


  # ============================================================================
  # Try redirecting missing methods to $page object. The purpose of
  # this is to allow accessing page's methods implicitly from the
  # test cases for example:   $page.logout if $page.user_is_logged?
  # would be simplified to:   logout if user_is_logged?
  #
  def method_missing method_name, *arguments, &block
    return super unless $page.respond_to? method_name
    $page.method(method_name).call(*arguments, &block)
  end


  def to_xml(builder)
    builder.testcase :classname => self.class, :name => self.name do
      case(self.status)
      when :fail then 
        builder.failure(self.message, :type => "exception")
      when :skip then
        builder.skipped
      end
      builder.tag!("system-out", self.stdout)
      builder.tag!("system-err", self.stderr)
    end
  end
end
