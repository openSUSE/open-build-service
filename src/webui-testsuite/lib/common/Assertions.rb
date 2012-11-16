# ==============================================================================
# Contains common assertation methods.
# All methods below rise AssertionError when an assertion isn't met and a
# SkipTestError when the current test has to be skipped.
#
module Assertions
  
  
  # ============================================================================
  # Repeatedly evaluates the given assertion block until 
  # it returns true or time exceeds. 
  # @param [String, nil] message optional message to be passed upon failure
  # @param [Block] block the assertion block must return true/false
  #
  # @example Validate that page source contains 'Hello world'
  #   validate { @driver.page_source.include? 'Hello World' }
  #
  def validate message=nil, &block
    time = Time.new
    begin
      result = block.call
      sleep 0.1 unless result
    end until result or time + $data[:asserts_timeout] < Time.new
    fail(message) unless result    
  end
  
  
  # ============================================================================
  # Fails the current test by raising an AssertionError exception
  # @param [String, nil] message optional message to be passed upon failure
  #
  def fail message=nil
    $page.navigate_to WebPage
    raise AssertionError, message
  end
  
  
  # ============================================================================
  # Asserts that the given boolean test is equal to true or fails.
  # @param [Boolean] test
  # @param [String, nil] message optional message to be passed upon failure
  #
  def assert test, message=nil
    message ||= test.to_s
    fail message unless test
  end
  
  
  def assert_equal valueA, valueB
    fail "not equal '#{valueA}' and '#{valueB}'" unless valueA == valueB
  end
  
  def assert_match pattern, string, message=""
    pattern = case(pattern)
              when String
                Regexp.new(Regexp.escape(pattern))
              else
                pattern
              end
    fail "<#{string}> expected to be =~\n<#{pattern}>." unless string =~ pattern
  end
end

class SkipTestError  < StandardError; end
class AssertionError < StandardError; end
