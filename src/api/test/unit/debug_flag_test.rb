require File.dirname(__FILE__) + '/../test_helper'

class DebugFlagTest < Test::Unit::TestCase
  fixtures :flags, :architectures, :db_projects, :db_packages
  
  def setup
    @project = DbProject.find(502)
    assert_kind_of DbProject, @project
    @package = DbPackage.find(10095)
    assert_kind_of DbPackage, @package
    @arch = Architecture.find(1)
    assert_kind_of Architecture, @arch    
  end
  
  # Replace this with your real tests.
  def test_add_debug_flag_to_project
    
    #checking precondition
    assert_equal 2, @project.debug_flags.size
    
    #create two new flags and save it.
    for i in 1..2 do
      f = DebugFlag.new(:repo => "10.#{i}", :status => "enabled")    
      @arch.debug_flags << f
      @project.debug_flags << f
    end
    
    @project.reload
      
    #check the result
    assert_equal 4, @project.debug_flags.size 
    
    f = @project.debug_flags[2]
    assert_kind_of DebugFlag, f
    
    assert_equal '10.1', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'enabled', f.status
    assert_equal @project.id, f.db_project_id
    assert_nil f.db_package_id
    assert_equal 3, f.position
    
    f = @project.debug_flags[3]
    assert_kind_of DebugFlag, f
    
    assert_equal '10.2', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'enabled', f.status
    assert_equal @project.id, f.db_project_id
    assert_nil f.db_package_id
    assert_equal 4, f.position
      
  end
  
  
  def test_add_debug_flag_to_package
    
    #checking precondition
    assert_equal 1, @package.debug_flags.size
    
    #create two new flags and save it.
    for i in 1..2 do
      f = DebugFlag.new(:repo => "10.#{i}", :status => "disabled")    
      @arch.debug_flags << f
      @package.debug_flags << f
    end
    
    @package.reload
      
    #check the result
    assert_equal 3, @package.debug_flags.size 
    
    f = @package.debug_flags[1]
    assert_kind_of DebugFlag, f
    
    assert_equal '10.1', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'disabled', f.status
    assert_equal @package.id, f.db_package_id
    assert_nil f.db_project_id
    assert_equal 2, f.position
    
    f = @package.debug_flags[2]
    assert_kind_of DebugFlag, f
    
    assert_equal '10.2', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'disabled', f.status
    assert_equal @package.id, f.db_package_id
    assert_nil f.db_project_id
    assert_equal 3, f.position
    
  end
  
  
  def test_delete_debug_flags_from_project
    
    #checking precondition
    assert_equal 2, @project.debug_flags.size
    #checking total number of flags stored in the database
    assert_equal 9, Flag.find(:all).size
    
    #destroy flags
    @project.debug_flags[1].destroy    
    #reload required!
    @project.reload
    assert_equal 1, @project.debug_flags.size
    assert_equal 8, Flag.find(:all).size
    
    @project.debug_flags[0].destroy
    #reload required
    @project.reload    
    assert_equal 0, @project.debug_flags.size    
    assert_equal 7, Flag.find(:all).size
  end
  
  
  def test_delete_debug_flags_from_package
    
    #checking precondition
    assert_equal 1, @package.debug_flags.size
    #checking total number of flags stored in the database
    assert_equal 9, Flag.find(:all).size    
    
    #destroy flags
    @package.debug_flags[0].destroy    
    #reload required!
    @package.reload
    assert_equal 0, @package.debug_flags.size
    assert_equal 8, Flag.find(:all).size
        
  end
  
  
  def test_delete_all_debug_flags_at_once_from_project
    
    #checking precondition
    assert_equal 2, @project.debug_flags.size
    #checking total number of flags stored in the database
    assert_equal 9, Flag.find(:all).size
    
    #destroy flags
    @project.debug_flags.destroy_all    
    #reload required!
    @project.reload
    assert_equal 0, @project.debug_flags.size
    assert_equal 7, Flag.find(:all).size
        
  end

    
  def test_delete_all_debug_flags_at_once_from_package
    
    #checking precondition
    assert_equal 1, @package.debug_flags.size
    #checking total number of flags stored in the database
    assert_equal 9, Flag.find(:all).size    
    
    #destroy flags
    @package.debug_flags.destroy_all    
    #reload required!
    @package.reload
    assert_equal 0, @package.debug_flags.size
    assert_equal 8, Flag.find(:all).size
        
  end
  
  
  def test_position
    # Because of each flag belongs_to architecture AND db_project|db_package for the 
    # position calculation it is important in which order the assignments
    # flag -> architecture and flag -> db_project|db_package are done.
    # If flag -> architecture is be done first, no flag position (in the list of
    # flags assigned to a object) can be calculated. This is because of no reference
    # (db_project_id or db_package_id) is set, which is needed for position calculation. 
    # The models should take this circumstances into consideration.
    
    #checking precondition
    assert_equal 2, @project.debug_flags.size
    assert_equal 1, @arch.debug_flags.size
    #checking total number of flags stored in the database
    assert_equal 9, Flag.find(:all).size    
    
    #create new flag and save it.
    f = DebugFlag.new(:repo => "10.3", :status => "enabled")    
    @arch.debug_flags << f
    @project.debug_flags << f
    
    @project.reload
    assert_equal 3, @project.debug_flags.size
    assert_equal 10, Flag.find(:all).size    
    @arch.reload
    assert_equal 2, @arch.debug_flags.size
    
    f.reload
    assert_equal 3, f.position
    
    #a flag update should not alter the flag position
    f.repo = '10.0'
    f.save
    
    f.reload
    assert_equal '10.0', f.repo
    assert_equal 3, f.position
    
    #create new flag and save it, but set the references in different order as above.
    #The result should be the same.
    f = DebugFlag.new(:repo => "10.2", :status => "enabled")    
    @project.debug_flags << f
    @arch.debug_flags << f

    @project.reload
    assert_equal 4, @project.debug_flags.size
    assert_equal 11, Flag.find(:all).size    
    @arch.reload
    assert_equal 3, @arch.debug_flags.size    
    
    f.reload
    assert_equal 4, f.position
    
    #a flag update should not alter the flag position
    f.repo = '10.1'
    f.save
    
    f.reload
    assert_equal '10.1', f.repo
    assert_equal 4, f.position    
    
  end
  
  
end