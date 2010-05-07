require File.dirname(__FILE__) + '/../unit_test_helper'
#http://blog.jayfields.com/2006/06/ruby-on-rails-unit-tests.html

class AttemptToAccessDbThrowsExceptionTest < UnitTest.TestCase
  def test_calling_the_db_causes_a_failure
    assert_raise(InvalidActionError) { ActiveRecord::Base.connection }
  end
end



class PackageTest < Test::Unit::TestCase

  def setup
    @package = Package.find(:name => "testpack")
    @package_with_flags_and_without_repo = Package.find(:name => "package_with_flags_and_without_repo")
    
  end
  
  
  #more than one project can be referenced through the class variable my_pro
  #(accessor/reader function is my_project)
  def test_my_project
    assert_equal 'home:tscholz', @package.my_project.name
    assert_equal "tscholz's Home Project", @package.my_project.title.to_s
  end
  
  
  def test_architectures
    assert_equal "i586", @package.architectures[0]
    assert_equal "x86_64", @package.architectures[1]
  end
  
  
  def test_repositories
    assert_equal "openSUSE_10.2", @package.repositories[0]
    assert_equal "openSUSE_Factory", @package.repositories[1]
    #the same again :)
    assert_equal "openSUSE_10.2", @package.my_project.repositories[0]
    assert_equal "openSUSE_Factory", @package.repositories[1]
  end
    
  
end
