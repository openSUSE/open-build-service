# ==============================================================================
# Provides functionality to find, load and run tests from one/many test-cases.
# @see TestCase
# @see HtmlReport
#
class TestRunner
  
  def self.set_limitto limitto
     @@limitto = limitto
  end 

  # ============================================================================
  # Runs all loaded tests. If block is given yields every test before
  # it's started and right after it's completed. That  gives an easy
  # way for any UI code to update its state during the execution.
  # @param [Block] optional status update block, if such given every test will
  #   be yielded twice to the block. Once before start and once after finish.
  #
  def self.run(stop_on_fail)
    raise "No tests added for run!" if @@tests.empty?
    @@status = :running
    skipped_tests = []
    teststorun = @@tests
    while !teststorun.empty? do
      test = teststorun.shift
      @@current_test = test.name
      unless @@limitto.nil? or @@limitto.include? test.name.to_s 
        unless @@results.has_key? test.name
           skipped_tests << test
        end
        next
      end
      yield test if block_given?
      test.run
      @@results[test.name] = test.status unless test.status == :rescheduled
      @@previous_test = @@current_test
      yield test if block_given?
      if test.status == :rescheduled
         teststorun = skipped_tests + [test] + teststorun
         test.status = :ready
         skipped_tests = []
      end
      if test.status == :fail && stop_on_fail.true?
	teststorun = []	
      end
    end
    @@current_test  = nil
    @@status        = :ready
  end
  
  
  # ============================================================================
  # Get the status of the runner.
  # @return [:ready, :running]
  def self.status
    @@status
  end


  # ============================================================================
  # Resets the TestRunner. Discards all results and loaded tests.
  #
  def self.reset
    @@tests         = []
    @@results       = {}
    @@limitto       = nil
    @@current_test  = nil
    @@previous_test = nil
    @@status        = :empty
  end


  # ============================================================================
  # Adds one or more tests to the runner's queue.
  # @param [TestCase, Array] test 
  #
  def self.add test
    raise ArgumentError unless test.is_a? TestCase or test.is_a? Array
    if test.is_a? Array
      test.each do |t|
        raise ArgumentError unless t.is_a? TestCase
        @tests << t
      end
    else
      @@tests << test
    end
    @@status = :ready unless @@tests.empty?
  end
  
  
  # ============================================================================
  # Collects all TestCase classes defined in the global object space and adds
  # all of their tests to the queue.
  #
  def self.add_all
    test_cases = []
    ObjectSpace.each_object(Class) do |object|
      if object.superclass and object.superclass <= TestCase
        test_cases << object
      end
    end
    test_cases = test_cases.sort_by {|tc| tc.to_s}
    test_cases.each { |tc| @@tests += tc.suite }
    @@status = :ready unless @@tests.empty?
  end
  
  
  # ============================================================================
  # Gets the currently running test if any.
  # @return [Symbol, nil] the name of the current test or nil.
  #
  def self.current_test
    @@current_test
  end


  # ============================================================================
  # Gets the name of the previously run test if there was such.
  # @return [Symbol, nil] the name of the previously run test or nil.
  #
  def self.previous_test
    @@previous_test
  end


  # ============================================================================
  # Gets the status of given test.
  # @param [Symbol] test_name
  # @return [:pass, :fail, :skip, :running] the status of the test in question
  #
  def self.status_of? test_name
    @@results[test_name]
  end


  def self.check_dependencies tests
     added_tests = false
     tests.each do |test|
        unless @@results.has_key? test
          @@limitto << test.to_s
          added_tests = true
        end
     end
     return added_tests
  end

  reset
   
   
end
