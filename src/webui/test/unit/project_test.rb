require File.dirname(__FILE__) + '/../unit_test_helper'
#http://blog.jayfields.com/2006/06/ruby-on-rails-unit-tests.html

class AttemptToAccessDbThrowsExceptionTest < UnitTest.TestCase
  def test_calling_the_db_causes_a_failure
    assert_raise(InvalidActionError) { ActiveRecord::Base.connection }
  end
end



class ProjectTest < Test::Unit::TestCase

  def setup
    @project = Project.find("home:tscholz")
  end

  
  def test_architectures
    assert_equal "i586", @project.architectures[0]
    assert_equal "x86_64", @project.architectures[1]
  end


  def test_repositories
    assert_equal "openSUSE_10.2", @project.repositories[0]
    assert_equal "openSUSE_Factory", @project.repositories[1]
  end
  
  def test_marshall
     t = Marshal.dump(@project)
     nproject = Marshal.load(t)
     assert_equal @project.dump_xml, nproject.dump_xml
     assert_equal @project.init_options, nproject.init_options
  end

end
