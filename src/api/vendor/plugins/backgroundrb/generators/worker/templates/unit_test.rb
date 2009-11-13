require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../test_helper'
require "#{RAILS_ROOT}/lib/workers/<%= file_name %>_worker"
require "#{RAILS_ROOT}/vendor/plugins/backgroundrb/lib/backgroundrb.rb"
require 'drb'

class <%= class_name %>WorkerTest < Test::Unit::TestCase

  # Replace this with your real tests.
  def test_truth
    assert <%= class_name %>Worker.included_modules.include?(DRbUndumped)
  end
end
