require File.dirname(__FILE__) + '/../test_helper'

class DebuginfoFlagTest < ActiveSupport::TestCase
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
    assert_equal 2, @project.debuginfo_flags.size
    
    #create two new flags and save it.
    for i in 1..2 do
      f = DebuginfoFlag.new(:repo => "10.#{i}", :status => "enabled", :position => i + 2)    
      @arch.debuginfo_flags << f
      @project.debuginfo_flags << f
    end
    
    @project.reload
      
    #check the result
    assert_equal 4, @project.debuginfo_flags.size 
    
    f = @project.debuginfo_flags[2]
    assert_kind_of DebuginfoFlag, f
    
    assert_equal '10.1', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'enabled', f.status
    assert_equal @project.id, f.db_project_id
    assert_nil f.db_package_id
    assert_equal 3, f.position
    
    f = @project.debuginfo_flags[3]
    assert_kind_of DebuginfoFlag, f
    
    assert_equal '10.2', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'enabled', f.status
    assert_equal @project.id, f.db_project_id
    assert_nil f.db_package_id
    assert_equal 4, f.position
      
  end
  
  
  def test_add_debug_flag_to_package
    
    #checking precondition
    assert_equal 1, @package.debuginfo_flags.size
    
    #create two new flags and save it.
    for i in 1..2 do
      f = DebuginfoFlag.new(:repo => "10.#{i}", :status => "disabled", :position => i+1)    
      @arch.debuginfo_flags << f
      @package.debuginfo_flags << f
    end
    
    @package.reload
      
    #check the result
    assert_equal 3, @package.debuginfo_flags.size 
    
    f = @package.debuginfo_flags[1]
    assert_kind_of DebuginfoFlag, f
    
    assert_equal '10.1', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'disabled', f.status
    assert_equal @package.id, f.db_package_id
    assert_nil f.db_project_id
    assert_equal 2, f.position
    
    f = @package.debuginfo_flags[2]
    assert_kind_of DebuginfoFlag, f
    
    assert_equal '10.2', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'disabled', f.status
    assert_equal @package.id, f.db_package_id
    assert_nil f.db_project_id
    assert_equal 3, f.position
    
  end
  
  
  def test_delete_debuginfo_flags_from_project
    
    #checking precondition
    assert_equal 2, @project.debuginfo_flags.size
    #checking total number of flags stored in the database
    count = Flag.find(:all).size
    
    #destroy flags
    @project.debuginfo_flags[1].destroy    
    #reload required!
    @project.reload
    assert_equal 1, @project.debuginfo_flags.size
    assert_equal 1, count - Flag.find(:all).size
    
    @project.debuginfo_flags[0].destroy
    #reload required
    @project.reload    
    assert_equal 0, @project.debuginfo_flags.size    
    assert_equal 2, count - Flag.find(:all).size
  end
  
  
  def test_delete_debuginfo_flags_from_package
    
    #checking precondition
    assert_equal 1, @package.debuginfo_flags.size
    #checking total number of flags stored in the database
    count = Flag.find(:all).size    
    
    #destroy flags
    @package.debuginfo_flags[0].destroy    
    #reload required!
    @package.reload
    assert_equal 0, @package.debuginfo_flags.size
    assert_equal 1, count - Flag.find(:all).size
        
  end
  
  
  def test_delete_all_debuginfo_flags_at_once_from_project
    
    #checking precondition
    assert_equal 2, @project.debuginfo_flags.size
    #checking total number of flags stored in the database
    count = Flag.find(:all).size
    
    #destroy flags
    @project.debuginfo_flags.destroy_all    
    #reload required!
    @project.reload
    assert_equal 0, @project.debuginfo_flags.size
    assert_equal 2, count - Flag.find(:all).size
        
  end

    
  def test_delete_all_debuginfo_flags_at_once_from_package
    
    #checking precondition
    assert_equal 1, @package.debuginfo_flags.size
    #checking total number of flags stored in the database
    count = Flag.find(:all).size    
    
    #destroy flags
    @package.debuginfo_flags.destroy_all    
    #reload required!
    @package.reload
    assert_equal 0, @package.debuginfo_flags.size
    assert_equal 1, count - Flag.find(:all).size
        
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
    assert_equal 2, @project.debuginfo_flags.size
    assert_equal 1, @arch.debuginfo_flags.size
    #checking total number of flags stored in the database
    count = Flag.find(:all).size    
    
    #create new flag and save it.
    f = DebuginfoFlag.new(:repo => "10.3", :status => "enabled", :position => 3)    
    @arch.debuginfo_flags << f
    @project.debuginfo_flags << f
    
    @project.reload
    assert_equal 3, @project.debuginfo_flags.size
    assert_equal 1, Flag.find(:all).size - count
    @arch.reload
    assert_equal 2, @arch.debuginfo_flags.size
    
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
    f = DebuginfoFlag.new(:repo => "10.2", :status => "enabled", :position => 4)    
    @project.debuginfo_flags << f
    @arch.debuginfo_flags << f

    @project.reload
    assert_equal 4, @project.debuginfo_flags.size
    assert_equal 2, Flag.find(:all).size - count
    @arch.reload
    assert_equal 3, @arch.debuginfo_flags.size    
    
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
