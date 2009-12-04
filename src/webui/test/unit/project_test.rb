require File.dirname(__FILE__) + '/../unit_test_helper'
#http://blog.jayfields.com/2006/06/ruby-on-rails-unit-tests.html

class AttemptToAccessDbThrowsExceptionTest < UnitTest.TestCase
  def test_calling_the_db_causes_a_failure
    assert_raise(InvalidActionError) { ActiveRecord::Base.connection }
  end
end



class ProjectTest < Test::Unit::TestCase

  def setup
    @project = Project.find(:name => "home:tscholz")

    @project_without_flags = Project.find(:name => "project_without_flags")

    @project_without_flags_and_repos = Project.find(:name => "project_without_flags_and_repos")
  end

  
  def test_set_default_flags
    @project.create_flag_matrix(:flagtype => 'build')

    #check the result
    #for build_flags
    assert_equal 9, @project.build_flags.size
    ['openSUSE_10.2::x86_64', 'all::all', 'openSUSE_Factory::all',
     'openSUSE_10.2::all', 'openSUSE_Factory::i586', 'all::i586',
     'openSUSE_Factory::x86_64', 'openSUSE_10.2::i586', 'all::x86_64'].each do |key|
       assert_kind_of Flag, @project.build_flags[key.to_sym]
     end

    @project.create_flag_matrix(:flagtype => 'publish')

    #for publish_flags
    assert_equal 9, @project.publish_flags.size
    ['openSUSE_10.2::x86_64', 'all::all', 'openSUSE_Factory::all',
     'openSUSE_10.2::all', 'openSUSE_Factory::i586', 'all::i586',
     'openSUSE_Factory::x86_64', 'openSUSE_10.2::i586', 'all::x86_64'].each do |key|
       assert_kind_of Flag, @project.publish_flags[key.to_sym]
     end
     
     @project.create_flag_matrix(:flagtype => 'debuginfo')
     
     #for debug_flags
     ['openSUSE_10.2::x86_64', 'all::all', 'openSUSE_Factory::all',
          'openSUSE_10.2::all', 'openSUSE_Factory::i586', 'all::i586',
          'openSUSE_Factory::x86_64', 'openSUSE_10.2::i586', 'all::x86_64'].each do |key|
            assert_kind_of Flag, @project.debuginfo_flags[key.to_sym]
     end     
     
  end


  def test_update_buildflag_matrix

    @project.create_flag_matrix(:flagtype => 'build')

    #check preconditions
    ['openSUSE_10.2::i586'].each do |key|
      flag = @project.build_flags[key.to_sym]
      assert_equal 'default', flag.status
    end

    #update flags with the project-config
    @project.update_flag_matrix(:flagtype => 'build')

    #check results
    ['openSUSE_10.2::i586'].each do |key|
      flag = @project.build_flags[key.to_sym]
      assert_equal 'enable', flag.status
    end
    
  end
  
  
  def test_update_publishflag_matrix
    
    project = Project.find(:name => "project_with_publishflags")

    project.create_flag_matrix(:flagtype => 'publish')

    #check preconditions
    ['openSUSE_10.2::i586'].each do |key|
      flag = project.publish_flags[key.to_sym]
      assert_equal 'default', flag.status
    end

    #update flags with the project-config
    project.update_flag_matrix(:flagtype => 'publish')

    #check results
    ['openSUSE_10.2::i586'].each do |key|
      flag = project.publish_flags[key.to_sym]
      assert_equal 'enable', flag.status
    end
    
  end  

  
  def test_update_debugflag_matrix
    
    project = Project.find(:name => "project_with_debugflags")

    project.create_flag_matrix(:flagtype => 'debuginfo')

    #check preconditions
    ['openSUSE_10.2::i586'].each do |key|
      flag = project.debuginfo_flags[key.to_sym]
      assert_equal 'default', flag.status
    end

    #update flags with the project-config
    project.update_flag_matrix(:flagtype => 'debuginfo')

    #check results
    ['openSUSE_10.2::i586'].each do |key|
      flag = project.debuginfo_flags[key.to_sym]
      assert_equal 'enable', flag.status
    end
    
  end    
  
  
  def test_update_useforbuildflag_matrix
    
    project = Project.find(:name => "project_with_useforbuildflags")

    project.create_flag_matrix(:flagtype => 'useforbuild')

    #check preconditions
    ['openSUSE_10.2::i586'].each do |key|
      flag = project.useforbuild_flags[key.to_sym]
      assert_equal 'default', flag.status
    end

    #update flags with the project-config
    project.update_flag_matrix(:flagtype => 'useforbuild')

    #check results
    ['openSUSE_10.2::i586'].each do |key|
      flag = project.useforbuild_flags[key.to_sym]
      assert_equal 'enable', flag.status
    end
    
  end
    
  
  def test_ignore_flags_on_update
    @project = Project.find(:name => "project_with_flags_and_improper_repo")
    
    @project.create_flag_matrix(:flagtype => 'build')
    
    assert_nothing_raised(NoMethodError){
       @project.update_flag_matrix(:flagtype => 'build')
    }
    
  end
  
  
  def test_find_flag_dependencies
    @project.create_flag_matrix(:flagtype => 'build')
    @project.update_flag_matrix(:flagtype => 'build')
    #puts @project.build_flags['all::x86_64'.to_sym].inspect

    assert_equal 'project default', @project.build_flags['openSUSE_10.2::x86_64'.to_sym].implicit_setter.description

  end


  def test_architectures
    assert_equal "i586", @project.architectures[0]
    assert_equal "x86_64", @project.architectures[1]
  end


  def test_repositories
    assert_equal "openSUSE_10.2", @project.repositories[0].name
    assert_equal "openSUSE_Factory", @project.repositories[1].name
  end

end
