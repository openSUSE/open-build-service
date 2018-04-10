# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class StatusHelperTest < ActiveSupport::TestCase
  test 'resample' do
    # it can't do magic
    assert_equal([], StatusHelper.resample([], 1000))

    now = 10_000
    testarray = []
    10.times do |i|
      testarray << [now - i * 10, i]
    end
    # [[10000, 0], [9990, 1], [9980, 2], [9970, 3], [9960, 4], [9950, 5], [9940, 6], [9930, 7], [9920, 8], [9910, 9]]
    # while the testarray increases, the timestamps go down, so the result needs to decrease
    assert_equal([[9910.0, 9.0], [9919.0, 8.0], [9928.0, 7.0],
                  [9937.0, 6.0], [9946.0, 5.0], [9955.0, 4.0],
                  [9964.0, 3.0], [9973.0, 2.0], [9982.0, 1.0],
                  [9991.0, 0.0]], StatusHelper.resample(testarray, 10))
    assert_equal([[9901.0, 9.0], [9919.0, 7.5], [9937.0, 5.5],
                  [9955.0, 3.5], [9973.0, 1.5]], StatusHelper.resample(testarray, 5))

    # now increase the last sequence
    testarray << [now + 1, 1000]
    assert_equal([[9900.9, 9.0], [9919.1, 7.5], [9937.300000000001, 5.5],
                  [9955.500000000002, 3.5], [9973.700000000003, 1.5]],
                 StatusHelper.resample(testarray, 5))

    # now add a gap
    testarray.delete [9980, 2]
    testarray.delete [9970, 3]
    testarray.delete [9960, 4]
    # the value stays the same in 2 intervals
    assert_equal([[9900.9, 9.0], [9919.1, 7.5], [9937.300000000001, 5.5],
                  [9955.500000000002, 5.5], [9973.700000000003, 1.0]],
                 StatusHelper.resample(testarray, 5))
  end
end
