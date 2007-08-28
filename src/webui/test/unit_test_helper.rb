ENV["RAILS_ENV"] = "test" 
require File.expand_path(File.dirname(__FILE__) + "/../config/environment") 
require 'application' 
require 'test/unit' 
require 'action_controller/test_process' 
require 'breakpoint'

class UnitTest
  def self.TestCase
    class << ActiveRecord::Base
      def connection
        raise InvalidActionError, 'You cannot access the database from a unit test', caller
      end
    end
    Test::Unit::TestCase
  end
end

class InvalidActionError < StandardError
end

#class Test::Unit::TestCase
##http://muness.blogspot.com/2006/12/unit-testing-rails-activerecord-classes.html
#  class ActiveRecordUnitTestHelper
#   attr_accessor :klass
#
#   def initialize klass
#     self.klass = klass
#     self
#   end
#
#   def where attributes
#     klass.stubs(:columns).returns(columns(attributes))
#     instance = klass.new(attributes)
#     instance.id = attributes[:id] if attributes[:id] #the id attributes works differently on active record classes
#     instance
#   end
#      
#      protected
#   def columns attributes
#     attributes.keys.collect{|attribute| column attribute.to_s, attributes[attribute]}
#   end
#
#   def column column_name, value
#     ActiveRecord::ConnectionAdapters::Column.new(
#  column_name, nil,
#  ActiveRecordUnitTestHelper.active_record_type(value.class), 
#  false)
#   end
#  
#   def self.active_record_type klass
#     return case klass.name
#       when "Fixnum"         then "integer"
#       when "Float"          then "float"
#       when "Time"           then "time"
#       when "Date"           then "date"
#       when "String"         then "string"
#       when "Object"         then "boolean"
#     end
#   end
# 	end
# 
# 	def disconnected klass
#		ActiveRecordUnitTestHelper.new(klass)
#	end
#end