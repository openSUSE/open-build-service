ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'application_controller'
require 'test/unit'
require 'action_controller/test_process'

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

