require File.dirname(__FILE__) + '/../unit_test_helper'
#http://blog.jayfields.com/2006/06/ruby-on-rails-unit-tests.html

class AttemptToAccessDbThrowsExceptionTest < UnitTest.TestCase
  def test_calling_the_db_causes_a_failure
    assert_raise(InvalidActionError) { ActiveRecord::Base.connection }
  end
end



class ProjectTest < Test::Unit::TestCase

	def setup
		@project = Project.new("
			<project name='home:tscholz'>
				<title>tscholz's Home Project</title>
				<description/>
				<build>
					<disable/>
					<enable repository='openSUSE_10.2' arch='i586'/>
				</build>
				<person userid='tscholz' role='maintainer'/>
				<repository name='openSUSE_10.2'>
					<path project='openSUSE:10.2' repository='standard'/>
					<arch>i586</arch>
					<arch>x86_64</arch>
				</repository>
				<repository name='openSUSE_Factory'>
					<path project='openSUSE:Factory' repository='standard'/>
					<arch>i586</arch>
					<arch>x86_64</arch>
				</repository>				
			</project>
		")		
		
		
		@project_without_flags = Project.new("
			<project name='home:tscholz'>
				<title>tscholz's Home Project</title>
				<description/>
				<person userid='tscholz' role='maintainer'/>
				<repository name='openSUSE_10.2'>
					<path project='openSUSE:10.2' repository='standard'/>
					<arch>i586</arch>
					<arch>x86_64</arch>
				</repository>
				<repository name='openSUSE_Factory'>
					<path project='openSUSE:Factory' repository='standard'/>
					<arch>i586</arch>
					<arch>x86_64</arch>
				</repository>				
			</project>
		")
		
		
		@project_without_flags_and_repos = Project.new("
				<project name='home:tscholz'>
					<title>tscholz's Home Project</title>
					<description/>
					<person userid='tscholz' role='maintainer'/>			
				</project>			
		")			
		
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
	end
	
	
	def test_update_flag_matrix
		
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