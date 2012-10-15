require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'json'
#require '/usr/lib64/ruby/gems/1.9.1/gems/perftools.rb-2.0.0/lib/perftools.so'

class ProjectTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @project = projects( :home_Iggy )
  end
    
  def test_flags_to_axml
    #check precondition
    assert_equal 2, @project.type_flags('build').size
    assert_equal 2, @project.type_flags('publish').size
    
    xml_string = @project.to_axml
    #puts xml_string
    
    #check the results
    assert_xml_tag xml_string, :tag => :project, :children => { :count => 1, :only => { :tag => :build } }
    assert_xml_tag xml_string, :parent => :project, :tag => :build, :children => { :count => 2 }

    assert_xml_tag xml_string, :tag => :project, :children => { :count => 1, :only => { :tag => :publish } }
    assert_xml_tag xml_string, :parent => :project, :tag => :publish, :children => { :count => 2 }

  end
  
  
  def test_add_new_flags_from_xml
    
    #precondition check
    @project.flags.delete_all
    @project.reload
    assert_equal 0, @project.flags.size
    
    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description></description> 
        <build> 
          <disable repository='10.2' arch='i586'/>
        </build>
        <publish>
          <enable repository='10.2' arch='x86_64'/>
        </publish>
        <debuginfo>
          <disable repository='10.0' arch='i586'/>
        </debuginfo>
      </project>"
      )
    
    position = 1
    ['build', 'publish', 'debuginfo'].each do |flagtype|
      position = @project.update_flags(axml, flagtype, position)
    end
    
    @project.save
    @project.reload
    
    #check results
    assert_equal 1, @project.type_flags('build').size
    assert_equal 'disable', @project.type_flags('build')[0].status
    assert_equal '10.2', @project.type_flags('build')[0].repo
    assert_equal 'i586', @project.type_flags('build')[0].architecture.name
    assert_equal 1, @project.type_flags('build')[0].position
    assert_nil @project.type_flags('build')[0].package    
    assert_equal 'home:Iggy', @project.type_flags('build')[0].project.name
    
    assert_equal 1, @project.type_flags('publish').size
    assert_equal 'enable', @project.type_flags('publish')[0].status
    assert_equal '10.2', @project.type_flags('publish')[0].repo
    assert_equal 'x86_64', @project.type_flags('publish')[0].architecture.name
    assert_equal 2, @project.type_flags('publish')[0].position
    assert_nil @project.type_flags('publish')[0].package    
    assert_equal 'home:Iggy', @project.type_flags('publish')[0].project.name  
    
    assert_equal 1, @project.type_flags('debuginfo').size
    assert_equal 'disable', @project.type_flags('debuginfo')[0].status
    assert_equal '10.0', @project.type_flags('debuginfo')[0].repo
    assert_equal 'i586', @project.type_flags('debuginfo')[0].architecture.name
    assert_equal 3, @project.type_flags('debuginfo')[0].position
    assert_nil @project.type_flags('debuginfo')[0].package    
    assert_equal 'home:Iggy', @project.type_flags('debuginfo')[0].project.name      
    
  end
  
  
  def test_delete_flags_through_xml
    #check precondition
    assert_equal 2, @project.type_flags('build').size
    assert_equal 2, @project.type_flags('publish').size
    
    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description></description> 
      </project>"
      )    
    
    @project.update_all_flags(axml)
    assert_equal 0, @project.type_flags('build').size
    assert_equal 0, @project.type_flags('publish').size
  end

    
  def test_store_axml
    original = @project.to_axml

    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description></description>
        <debuginfo>
          <disable repository='10.0' arch='i586'/>
        </debuginfo>    
        <url></url>
        <disable/>
      </project>"
      )
      
    @project.update_from_xml(axml)
    
    assert_equal 0, @project.type_flags('build').size
    assert_equal 1, @project.type_flags('debuginfo').size        

    @project.update_from_xml(Xmlhash.parse(original))
  end  

  def test_ordering
    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description></description>
        <repository name='images'>
          <arch>local</arch>
          <arch>i586</arch>
          <arch>x86_64</arch>
        </repository>
      </project>"
      )
    @project.update_from_xml(axml)
    
    xml = @project.render_axml
    
    # validate i586 is in the middle
    assert_xml_tag xml, :tag => :arch, :content => 'i586', :after => { :tag => :arch, :content => 'local' }
    assert_xml_tag xml, :tag => :arch, :content => 'i586', :before => { :tag => :arch, :content => 'x86_64' }
    
    # now verify it's not happening randomly
    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description></description>
        <repository name='images'>
          <arch>i586</arch>
          <arch>x86_64</arch>
          <arch>local</arch>
        </repository>
      </project>"
      )
    @project.update_from_xml(axml)

    xml = @project.render_axml
    
    # validate x86_64 is in the middle
    assert_xml_tag xml, :tag => :arch, :content => 'x86_64', :after => { :tag => :arch, :content => 'i586' }
    assert_xml_tag xml, :tag => :arch, :content => 'x86_64', :before => { :tag => :arch, :content => 'local' }
    
  end
    
  def test_benchmark_all
    prjs = Project.find :all
    #PerfTools::CpuProfiler.start("/tmp/profile") do
      x = Benchmark.realtime { prjs.each { |p| p.expand_flags.to_json } }
      y = Benchmark.realtime { prjs.each { |p| p.to_axml('flagdetails') } }
    #end
    puts "#{x} #{y}"
  end

  def test_create_maintenance_project_and_maintained_project
    maintenance_project = Project.new(:name => 'Maintenance:Project')
    assert_equal true, maintenance_project.set_project_type('maintenance')
    assert_equal 'maintenance', maintenance_project.project_type()

    # Create a project for which maintenance is done (i.e. a maintained project)
    maintained_project = Project.new(:name => 'Maintained:Project')
    assert_equal true, maintained_project.set_maintenance_project(maintenance_project)
    assert_equal true, maintained_project.set_maintenance_project(maintenance_project.name)
    assert_equal maintenance_project, maintained_project.maintenance_project()
  end
  
  
  #helper
  def put_flags(flags)
    flags.each do |flag|
      if flag.architecture.nil?
        puts "#{flag} \t #{flag.id} \t #{flag.status} \t #{flag.architecture} \t #{flag.repo} \t #{flag.position}"
      else
        puts "#{flag} \t #{flag.id} \t #{flag.status} \t #{flag.architecture.name} \t #{flag.repo} \t #{flag.position}"
      end
    end
  end  
  
  
end


