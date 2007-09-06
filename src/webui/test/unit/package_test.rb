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
  
  
  def test_set_default_flags        

    #weiter mit:
    # project.find funzt ned, wenn in der create_flag_matrix funktion das projekt instantiiert werden soll
    #11:00 deploy!
    
    @package.create_flag_matrix(:flagtype => 'build')
        
    #check the result
    #for build_flags
    assert_equal 9, @package.build_flags.size
    ['openSUSE_10.2::x86_64', 'all::all', 'openSUSE_Factory::all',
     'openSUSE_10.2::all', 'openSUSE_Factory::i586', 'all::i586',
     'openSUSE_Factory::x86_64', 'openSUSE_10.2::i586', 'all::x86_64'].each do |key|
       assert_kind_of Flag, @package.build_flags[key.to_sym]
     end
     
    @package.create_flag_matrix(:flagtype => 'publish')
    
    #for publish_flags
    assert_equal 9, @package.publish_flags.size
    ['openSUSE_10.2::x86_64', 'all::all', 'openSUSE_Factory::all',
     'openSUSE_10.2::all', 'openSUSE_Factory::i586', 'all::i586',
     'openSUSE_Factory::x86_64', 'openSUSE_10.2::i586', 'all::x86_64'].each do |key|
       assert_kind_of Flag, @package.publish_flags[key.to_sym]
     end    
  end
  
  
  def test_update_flag_matrix
    
    @package.create_flag_matrix(:flagtype => 'build')
    
    #check preconditions
    ['openSUSE_10.2::i586'].each do |key|    
      flag = @package.build_flags[key.to_sym]
      assert_equal 'default', flag.status
    end
    
    #update flags with the package-config
    @package.update_flag_matrix(:flagtype => 'build')
    
    #check results (only some tests)
    assert_equal 'disable', @package.buildflags['all::all'.to_sym].status
    assert_equal 'disable', @package.buildflags['all::i586'.to_sym].status
    assert_equal 'enable', @package.buildflags['openSUSE_Factory::i586'.to_sym].status
    
    #check a project-flag (transitive), exists due to the project config
    assert_equal 'default', @package.buildflags['openSUSE_10.2::i586'.to_sym].status    
    
    #check some publish flags
    @package.update_flag_matrix(:flagtype => 'publish')    
    assert_equal 'enable', @package.publishflags['openSUSE_10.2::x86_64'.to_sym].status
    assert_equal 'default', @package.publishflags['all::all'.to_sym].status
    assert_equal true, @package.publishflags['all::all'.to_sym].enabled?
    
  end

  
  def test_find_implicit_setter
    @package.create_flag_matrix(:flagtype => 'build')
    @package.update_flag_matrix(:flagtype => 'build')
    
    assert_equal 'project default', @package.buildflags['all::all'.to_sym].implicit_setter.description
    assert_equal 'package default', @package.buildflags['all::i586'.to_sym].implicit_setter.description 
    assert_equal 'package default', @package.buildflags['openSUSE_Factory::all'.to_sym].implicit_setter.description
    assert_equal 'package default', @package.buildflags['openSUSE_10.2::x86_64'.to_sym].implicit_setter.description
  end
  
  
  def test_package_with_flags_but_without_repo
    assert_raises (RuntimeError){
      @package_with_flags_and_without_repo.create_flag_matrix(:flagtype => 'build')
    }
  end  
  
  
  #more than one project can be referenced through the class variable my_pro
  #(accessor/reader function is my_project)
  def test_my_project
    assert_equal 'home:tscholz', @package.my_project.name
    assert_equal "tscholz's Home Project", @package.my_project.title.to_s
    assert_equal 'project_with_flags_and_without_repo', @package_with_flags_and_without_repo.my_project.name
    assert_equal "", @package_with_flags_and_without_repo.my_project.title.to_s
  end
  
  
  def test_architectures
    assert_equal "i586", @package.architectures[0]
    assert_equal "x86_64", @package.architectures[1]
  end
  
  
  def test_repositories
    assert_equal "openSUSE_10.2", @package.repositories[0].name
    assert_equal "openSUSE_Factory", @package.repositories[1].name    
  end
      
end