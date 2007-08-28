require File.dirname(__FILE__) + '/../unit_test_helper'
#http://blog.jayfields.com/2006/06/ruby-on-rails-unit-tests.html

class AttemptToAccessDbThrowsExceptionTest < UnitTest.TestCase
  def test_calling_the_db_causes_a_failure
    assert_raise(InvalidActionError) { ActiveRecord::Base.connection }
  end
end


class FlagTest < Test::Unit::TestCase

	def test_implicit_setter_project
		
		projDefault = Flag.new
		projDefault.name = 'Project Default'
		projDefault.status = 'enable'
		projDefault.explicit = true

		projRepoDefault = Flag.new
		projRepoDefault.name = 'Project Repository Default'
		projRepoDefault.status = 'default'
		projRepoDefault.explicit = false
		projRepoDefault.set_implicit_setters(projDefault)		

		projArchDefault = Flag.new
		projArchDefault.name = 'Project Archiv Default'
		projArchDefault.status = 'default'
		projArchDefault.explicit = false
		projArchDefault.set_implicit_setters(projDefault)		
		
		repo_arch_flag = Flag.new
		repo_arch_flag.name = 'Standard Flag'
		repo_arch_flag.status = 'default'
		repo_arch_flag.explicit = false
		repo_arch_flag.set_implicit_setters(projRepoDefault, projArchDefault)			
		
		#through project default
		assert_equal 'Project Default', repo_arch_flag.implicit_setter.name
		assert_equal 'enable', repo_arch_flag.implicit_setter.status
		
		#through repo default
		projRepoDefault.status = 'enable'
		projRepoDefault.explicit = true		
		
		assert_equal 'Project Repository Default', repo_arch_flag.implicit_setter.name
		assert_equal 'enable', repo_arch_flag.implicit_setter.status		
		
		#reset repo default
		projRepoDefault.status = 'default'
		projRepoDefault.explicit = false			
		
		#through arch default
		projArchDefault.status = 'enable'
		projArchDefault.explicit = true		
		
		assert_equal 'Project Archiv Default', repo_arch_flag.implicit_setter.name
		assert_equal 'enable', repo_arch_flag.implicit_setter.status		
		
		#reset arch default
		projArchDefault.status = 'default'
		projArchDefault.explicit = false				
		
		
		#repo is explicit set...but status = disabled and arch is explicit set and enabled.
		#arch should be returned!
		projRepoDefault.status = 'disable'
		projRepoDefault.explicit = true		
		
		projArchDefault.status = 'enable'
		projArchDefault.explicit = true	
		
		assert_equal 'Project Archiv Default', repo_arch_flag.implicit_setter.name
		assert_equal 'enable', repo_arch_flag.implicit_setter.status		
		
		
		#if both enabled, repo default should be returned.
		projRepoDefault.status = 'enable'
		projRepoDefault.explicit = true			
		
		assert_equal 'Project Repository Default', repo_arch_flag.implicit_setter.name
		assert_equal 'enable', repo_arch_flag.implicit_setter.status			
		
	end
	
	
	def test_implicit_setter
		
		projDefault = Flag.new
		projDefault.name = 'Project Default'
		projDefault.status = 'enable'
		projDefault.explicit = true
		
		projRepoDefault = Flag.new
		projRepoDefault.name = 'Project Repository Default'
		projRepoDefault.status = 'default'
		projRepoDefault.explicit = false
		projRepoDefault.set_implicit_setters(projDefault)		
		
		projArchDefault = Flag.new
		projArchDefault.name = 'Project Architecture Default'
		projArchDefault.status = 'default'
		projArchDefault.explicit = false
		projArchDefault.set_implicit_setters(projDefault)		
		
		packDefault = Flag.new
		packDefault.name = 'Package Default'
		packDefault.status = 'default'
		packDefault.explicit = false
		packDefault.set_implicit_setters(projDefault)		
		
		packRepoDefault = Flag.new
		packRepoDefault.name = 'Package Repository Default'
		packRepoDefault.status = 'default'
		packRepoDefault.explicit = false
		packRepoDefault.set_implicit_setters(packDefault, projRepoDefault)				
		
		packArchDefault = Flag.new
		packArchDefault.name = 'Package Architecture Default'
		packArchDefault.status = 'default'
		packArchDefault.explicit = false
		packArchDefault.set_implicit_setters(packDefault, projArchDefault)		
		
		proj_repo_arch_flag = Flag.new
		proj_repo_arch_flag.name = 'Standard Flag (Project)'
		proj_repo_arch_flag.status = 'default'
		proj_repo_arch_flag.explicit = false
		proj_repo_arch_flag.set_implicit_setters(projRepoDefault, projArchDefault)				
		
		pack_repo_arch_flag = Flag.new
		pack_repo_arch_flag.name = 'Standard Flag (Package)'
		pack_repo_arch_flag.status = 'default'
		pack_repo_arch_flag.explicit = false
		pack_repo_arch_flag.set_implicit_setters(packRepoDefault, packArchDefault, packDefault, proj_repo_arch_flag)		
		
		#only the project default is defined....
		assert_equal 'Project Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status
		
		#project repo default is the setter
		projRepoDefault.status = 'disable'
		projRepoDefault.explicit = true		
		
		assert_equal 'Project Repository Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'disable', pack_repo_arch_flag.implicit_setter.status
		
		#reset project repo default		
		projRepoDefault.status = 'default'
		projRepoDefault.explicit = false	
		
		#project arch default is the setter
		projArchDefault.status = 'enable'
		projArchDefault.explicit = true	
		
		assert_equal 'Project Architecture Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status				
		
		#reset project arch default	
		projArchDefault.status = 'default'
		projArchDefault.explicit = false			
		
		#project repo default and project arch default are the setters, combinations
		# of enabled and disabled have to be tested
		projRepoDefault.status = 'disable'
		projRepoDefault.explicit = true			
		projArchDefault.status = 'disable'
		projArchDefault.explicit = true
		
		assert_equal 'Project Repository Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'disable', pack_repo_arch_flag.implicit_setter.status						
		
		projRepoDefault.status = 'disable'
		projRepoDefault.explicit = true			
		projArchDefault.status = 'enable'
		projArchDefault.explicit = true		
		
		assert_equal 'Project Architecture Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status
		
		projRepoDefault.status = 'enable'
		projRepoDefault.explicit = true			
		projArchDefault.status = 'enable'
		projArchDefault.explicit = true				
		
		assert_equal 'Project Repository Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status				
		
		#reset project repo default		
		projRepoDefault.status = 'default'
		projRepoDefault.explicit = false			
		#reset project arch default	
		projArchDefault.status = 'default'
		projArchDefault.explicit = false			
				
		#package default acts as setter
		packDefault.status = 'disable'
		packDefault.explicit = true	
		
		assert_equal 'Package Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'disable', pack_repo_arch_flag.implicit_setter.status				
		
		
		#package default and package repo default acts as setter
		packDefault.status = 'disable'
		packDefault.explicit = true			
		packRepoDefault.status = 'disable'	
		packRepoDefault.explicit = true
		
		assert_equal 'Package Repository Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'disable', pack_repo_arch_flag.implicit_setter.status					
		
		#TODO is this correct?  
		packDefault.status = 'enable'
		packDefault.explicit = true			
		packRepoDefault.status = 'disable'	
		packRepoDefault.explicit = true		
		
		assert_equal 'Package Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status
		
		packDefault.status = 'disable'
		packDefault.explicit = true			
		packRepoDefault.status = 'enable'	
		packRepoDefault.explicit = true		
		
		assert_equal 'Package Repository Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status		
		
		packDefault.status = 'enable'
		packDefault.explicit = true			
		packRepoDefault.status = 'enable'	
		packRepoDefault.explicit = true		
		
		assert_equal 'Package Repository Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status				
		
		#reset package default		
		packDefault.status = 'enable'
		packDefault.explicit = true				
		#reset package repo default	
		packRepoDefault.status = 'default'
		packRepoDefault.explicit = false			
		
		
		#package default and package arch default acts as setter
		packDefault.status = 'disable'
		packDefault.explicit = true			
		packArchDefault.status = 'disable'	
		packArchDefault.explicit = true
		
		assert_equal 'Package Architecture Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'disable', pack_repo_arch_flag.implicit_setter.status					
		
		#TODO is this correct?  
		packDefault.status = 'enable'
		packDefault.explicit = true			
		packArchDefault.status = 'disable'	
		packArchDefault.explicit = true		
		
		assert_equal 'Package Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status
		
		packDefault.status = 'disable'
		packDefault.explicit = true			
		packArchDefault.status = 'enable'	
		packArchDefault.explicit = true		
		
		assert_equal 'Package Architecture Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status		
		
		packDefault.status = 'enable'
		packDefault.explicit = true			
		packArchDefault.status = 'enable'	
		packArchDefault.explicit = true		
		
		assert_equal 'Package Architecture Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status		
		
		#reset package default		
		packDefault.status = 'default'
		packDefault.explicit = false				
		#reset package arch default	
		packArchDefault.status = 'default'
		packArchDefault.explicit = false		
		
		
		#the proj_repo_arch_flag acts as setter for the repo-arch-package flag
		proj_repo_arch_flag.status = 'enable'
		proj_repo_arch_flag.explicit = true
		
		assert_equal 'Standard Flag (Project)', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'enable', pack_repo_arch_flag.implicit_setter.status				
		
		#the proj_repo_arch_flag will be overwritten by the package default flag
		packDefault.status = 'disable'
		packDefault.explicit = true		
		
		assert_equal 'Package Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'disable', pack_repo_arch_flag.implicit_setter.status							
		
		#reset package default		
		packDefault.status = 'default'
		packDefault.explicit = false			
		
		
		#the proj_repo_arch_flag will be overwritten by the package repo default flag
		proj_repo_arch_flag.status = 'enable'
		proj_repo_arch_flag.explicit = true		
		packRepoDefault.status = 'disable'
		packRepoDefault.explicit = true
		
		assert_equal 'Package Repository Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'disable', pack_repo_arch_flag.implicit_setter.status
		
		#reset package arch default	
		packRepoDefault.status = 'default'
		packRepoDefault.explicit = false			
		
		#the proj_repo_arch_flag will be overwritten by the package arch default flag
		proj_repo_arch_flag.status = 'enable'
		proj_repo_arch_flag.explicit = true		
		packArchDefault.status = 'disable'
		packArchDefault.explicit = true
		
		assert_equal 'Package Architecture Default', pack_repo_arch_flag.implicit_setter.name
		assert_equal 'disable', pack_repo_arch_flag.implicit_setter.status
		
		#reset package arch default	
		packArchDefault.status = 'default'
		packArchDefault.explicit = false							
		
	end
		
	
	def test_simple_disabled?
		flag = Flag.new
		flag.name = 'flag'
		flag.status = 'disable'
		flag.explicit = true
		
		assert_equal true, flag.disabled?	
		
		flag.status = 'enable'
		
		assert_equal false, flag.disabled?	
	end
	
	
	#implicit disabled through only one parent
	def test_implicit_disabled?
		parent = Flag.new
		parent.name = 'parent'
		parent.status = 'disable'
		parent.explicit = true
		
		flag = Flag.new
		flag.name = 'flag'
		flag.status = 'default'
		flag.explicit = false
		flag.set_implicit_setters(parent)
		
		assert_equal true, flag.disabled?
		
		parent.status = 'enable'
		assert_equal false, flag.disabled?
	end
	
	
	def test_implicit_implicit_disabled?
		parent = Flag.new
		parent.name = 'parent'
		parent.status = 'disable'
		parent.explicit = true		
		
		parentA = Flag.new
		parentA.name = 'parentA'
		parentA.status = 'default'
		parentA.explicit = false
		parentA.set_implicit_setters(parent)		
		
		flag = Flag.new
		flag.name = 'flag'
		flag.status = 'default'
		flag.explicit = false
		flag.set_implicit_setters(parentA)
		
		assert_equal true, flag.disabled?	
		
		parent.status = 'enable'
		assert_equal false, flag.disabled?	
	end
	
	
	def test_implicit_disabled_two_parents
		parentA = Flag.new
		parentA.name = 'parentA'
		parentA.status = 'disable'
		parentA.explicit = true
		
		parentB = Flag.new
		parentB.name = 'parentB'
		parentB.status = 'disable'
		parentB.explicit = true
		
		flag = Flag.new
		flag.name = 'flag'
		flag.status = 'default'
		flag.explicit = false
		flag.set_implicit_setters(parentA, parentB)
		
		assert_equal true, flag.disabled?	
		
		parentA.status = 'enable'
		assert_equal false, flag.disabled?	
		
		parentA.status = 'enable'
		parentB.status = 'enable'
		assert_equal false, flag.disabled?		
		
		#'enabled' wins!
		parentA.status = 'disable'
		parentB.status = 'enable'
		assert_equal false, flag.disabled?
	end
	
	
	def test_enabled
		parentA = Flag.new
		parentA.name = 'parentA'
		parentA.status = 'enable'
		parentA.explicit = true
		
		parentB = Flag.new
		parentB.name = 'parentB'
		parentB.status = 'enable'
		parentB.explicit = true
		
		flag = Flag.new
		flag.name = 'flag'
		flag.status = 'default'
		flag.explicit = false
		flag.set_implicit_setters(parentA, parentB)
		
		assert_equal true, flag.enabled?	
		
		parentA.status = 'disable'
		parentB.status = 'disable'
		assert_equal false, flag.enabled?		
		
		#'enabled' wins!
		parentA.status = 'disable'
		parentB.status = 'enable'
		assert_equal true, flag.enabled?
		
		#'enabled' wins!
		parentA.status = 'enable'
		parentB.status = 'disable'
		assert_equal true, flag.enabled?		
	end
end
