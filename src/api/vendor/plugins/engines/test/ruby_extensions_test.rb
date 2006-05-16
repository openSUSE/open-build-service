ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + '/../../../../config/environment')
require 'test_help'

class RubyExtensionsTest < Test::Unit::TestCase

  def setup
    # create the module to be used for config testing
    eval "module TestModule end"
  end  

  def teardown
    # remove the TestModule constant from our scope
    self.class.class_eval { remove_const :TestModule }
  end


  #
  # Module.config
  #

  def test_config_no_arguments
    assert_raise(RuntimeError) { TestModule.config }
  end
  
  def test_config_array_arguments
    TestModule.config :monkey, 123
    assert_equal(123, TestModule.config(:monkey))
  end
  
  def test_config_hash_arguments
    TestModule.config :monkey => 123, :donkey => 456
    assert_equal(123, TestModule.config(:monkey))
    assert_equal(456, TestModule.config(:donkey))
  end

  def test_config_can_store_hash
    TestModule.config :hash, :key1 => 'val1', :key2 => 'val2'
    assert_equal({:key1 => 'val1', :key2 => 'val2'}, TestModule.config(:hash))
  end
    
  def test_config_cant_overwrite_existing_config_values
    TestModule.config :monkey, 123
    assert_equal(123, TestModule.config(:monkey))
    TestModule.config :monkey, 456
    assert_equal(123, TestModule.config(:monkey))
    
    TestModule.config :monkey => 456
    assert_equal(123, TestModule.config(:monkey))    
    
    # in this case, the resulting Hash only has {:baboon => "goodbye!"} - that's Ruby, users beware.
    TestModule.config :baboon => "hello", :baboon => "goodbye!"
    assert_equal("goodbye!", TestModule.config(:baboon))    
  end
  
  def test_config_force_new_value
    TestModule.config :monkey, 123
    TestModule.config :man, 321
    assert_equal(123, TestModule.config(:monkey))
    assert_equal(321, TestModule.config(:man))
    TestModule.config :monkey, 456, :force
    assert_equal(456, TestModule.config(:monkey))  
    TestModule.config :monkey => 456, :man => 654, :force => true
    assert_equal(456, TestModule.config(:monkey))
    assert_equal(654, TestModule.config(:man))      
    TestModule.config :monkey => 789, :man => 987, :force => false
    assert_equal(456, TestModule.config(:monkey))
    assert_equal(654, TestModule.config(:man))
    
    TestModule.config :hash, :key1 => 'val1', :key2 => 'val2'
    assert_equal({:key1 => 'val1', :key2 => 'val2'}, TestModule.config(:hash))
    TestModule.config :hash => {:key1 => 'val3', :key2 => 'val4'}, :force => true
    assert_equal({:key1 => 'val3', :key2 => 'val4'}, TestModule.config(:hash))           
  end
  
  # this test is somewhat redundant, but it might be an idea to havbe it explictly anyway
  def test_config_get_values
    TestModule.config :monkey, 123
    assert_equal(123, TestModule.config(:monkey))
  end
  
  def test_config_get_multiple_values
    TestModule.config :monkey, 123
    TestModule.config :donkey, 456
    assert_equal([123, 456], TestModule.config([:monkey, :donkey]))
  end
  
  
  #
  # Module.default_constant
  #
  
  def test_default_constant_set
    TestModule.default_constant :Monkey, 123
    assert_equal(123, TestModule::Monkey)
    TestModule.default_constant "Hello", 456
    assert_equal(456, TestModule::Hello)
  end

  def test_default_constant_cannot_set_again
    TestModule.default_constant :Monkey, 789
    assert_equal(789, TestModule::Monkey)
    TestModule.default_constant :Monkey, 456
    assert_equal(789, TestModule::Monkey)
  end

  def test_default_constant_bad_arguments
    # constant names must be Captialized
    assert_raise(NameError) { TestModule.default_constant :lowercase_name, 123 }
    
    # constant names should be given as Strings or Symbols
    assert_raise(RuntimeError) { TestModule.default_constant 123, 456 }
    assert_raise(RuntimeError) { TestModule.default_constant Object.new, 456 }
  end
end
