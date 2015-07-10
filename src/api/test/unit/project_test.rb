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
    User.current = users( :Iggy )
    
    #precondition check
    @project.flags.delete_all
    @project.reload
    assert_equal 0, @project.flags.size
    
    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
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
    %w(build publish debuginfo).each do |flagtype|
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
    User.current = users( :Iggy )

    #check precondition
    assert_equal 2, @project.type_flags('build').size
    assert_equal 2, @project.type_flags('publish').size
    
    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
      </project>"
      )    
    
    @project.update_all_flags(axml)
    assert_equal 0, @project.type_flags('build').size
    assert_equal 0, @project.type_flags('publish').size
  end

    
  def test_store_axml
    User.current = users( :Iggy )

    original = @project.to_axml

    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
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
    User.current = users( :Iggy )

    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <repository name='images'>
          <arch>local</arch>
          <arch>i586</arch>
          <arch>x86_64</arch>
        </repository>
      </project>"
      )
    @project.update_from_xml(axml)
    @project.reload
    
    xml = @project.render_xml
    
    # validate i586 is in the middle
    assert_xml_tag xml, :tag => :arch, :content => 'i586', :after => { :tag => :arch, :content => 'local' }
    assert_xml_tag xml, :tag => :arch, :content => 'i586', :before => { :tag => :arch, :content => 'x86_64' }
    
    # now verify it's not happening randomly
    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <repository name='images'>
          <arch>i586</arch>
          <arch>x86_64</arch>
          <arch>local</arch>
        </repository>
      </project>"
      )
    @project.update_from_xml(axml)

    xml = @project.render_xml
    
    # validate x86_64 is in the middle
    assert_xml_tag xml, :tag => :arch, :content => 'x86_64', :after => { :tag => :arch, :content => 'i586' }
    assert_xml_tag xml, :tag => :arch, :content => 'x86_64', :before => { :tag => :arch, :content => 'local' }
    
  end
    
  def test_maintains
    User.current = users( :Iggy )

    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <maintenance>
          <maintains project='BaseDistro'/>
        </maintenance>
      </project>"
      )
    @project.update_from_xml(axml)
    @project.reload
    xml = @project.render_xml
    assert_xml_tag xml, :tag => :maintains, :attributes => { :project => "BaseDistro" }

    # add one maintained project
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <maintenance>
          <maintains project='BaseDistro'/>
          <maintains project='BaseDistro2.0'/>
        </maintenance>
      </project>"
      )
    @project.update_from_xml(axml)
    @project.reload
    xml = @project.render_xml
    assert_xml_tag xml, :tag => :maintains, :attributes => { :project => "BaseDistro" }
    assert_xml_tag xml, :tag => :maintains, :attributes => { :project => "BaseDistro2.0" }

    # remove one maintained project
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <maintenance>
          <maintains project='BaseDistro2.0'/>
        </maintenance>
      </project>"
      )
    @project.update_from_xml(axml)
    @project.reload
    xml = @project.render_xml
    assert_no_xml_tag xml, :tag => :maintains, :attributes => { :project => "BaseDistro" }
    assert_xml_tag xml, :tag => :maintains, :attributes => { :project => "BaseDistro2.0" }
    assert_xml_tag xml, :tag => :maintenance

    # drop entire <maintenance> defs
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
      </project>"
      )
    @project.update_from_xml(axml)
    @project.reload
    xml = @project.render_xml
    assert_no_xml_tag xml, :tag => :maintenance
  end

  test "duplicated repos" do
     User.current = users( :king )
     orig = @project.render_xml

     axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <repository name='10.2'>
          <arch>x86_64</arch>
        </repository>
        <repository name='10.2'>
          <arch>i586</arch>
        </repository>
      </project>"
      )
     assert_raise(ActiveRecord::RecordInvalid) do
       Project.transaction do
         @project.update_from_xml(axml)
       end
     end
     @project.reload
     assert_equal orig, @project.render_xml
  end

  test "duplicated repos with remote" do
     User.current = users( :Iggy )
     orig = @project.render_xml

     xml = <<END
<project name="home:Iggy">
  <title>Iggy"s Home Project</title>
  <description>dummy</description>
  <repository name="remote_1">
    <path project="RemoteInstance:remote_project_1" repository="standard"/>
    <arch>i586</arch>
  </repository>
  <repository name="remote_1">
    <path project="RemoteInstance:remote_project_1" repository="standard"/>
    <arch>x86_64</arch>
  </repository>
</project>
END
     axml = Xmlhash.parse(xml)
     assert_raise(ActiveRecord::RecordInvalid) do
       Project.transaction do
         @project.update_from_xml(axml)
       end
     end
     @project.reload
     assert_equal orig, @project.render_xml
  end
  test "not duplicated repos with remote" do
     User.current = users( :Iggy )
     xml = <<END
<project name="home:Iggy">
  <title>Iggy"s Home Project</title>
  <description>dummy</description>
  <repository name="remote_2">
    <path project="RemoteInstance:remote_project_2" repository="standard"/>
    <arch>x86_64</arch>
    <arch>i586</arch>
  </repository>
  <repository name="remote_1">
    <path project="RemoteInstance:remote_project_1" repository="standard"/>
    <arch>x86_64</arch>
    <arch>i586</arch>
  </repository>
</project>
END
     axml = Xmlhash.parse(xml)
     Project.transaction do
       @project.update_from_xml(axml)
     end
     @project.reload
     assert_equal xml, @project.render_xml
  end

  def test_create_maintenance_project_and_maintained_project
    User.current = users( :king )
    maintenance_project = Project.new(:name => 'Maintenance:Project')
    assert_equal true, maintenance_project.set_project_type('maintenance')
    assert_equal 'maintenance', maintenance_project.project_type()
  end
  
  def test_handle_project_links
    User.current = users( :Iggy )

    # project A
    axml = Xmlhash.parse(
      "<project name='home:Iggy:A'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <link project='home:Iggy' />
      </project>"
      )
    projectA = Project.create( :name => "home:Iggy:A" )
    projectA.update_from_xml(axml)
    projectA.save!
    # project B
    axml = Xmlhash.parse(
      "<project name='home:Iggy:B'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <link project='home:Iggy:A' />
      </project>"
      )
    projectB = Project.create( :name => "home:Iggy:B" )
    projectB.update_from_xml(axml)
    projectB.save!

    # validate xml
    xml_string = projectA.to_axml
    assert_xml_tag xml_string, :tag => :link, :attributes => { :project => "home:Iggy" }
    xml_string = projectB.to_axml
    assert_xml_tag xml_string, :tag => :link, :attributes => { :project => "home:Iggy:A" }

    projectA.destroy
    projectB.reload
    xml_string = projectB.to_axml
    assert_no_xml_tag xml_string, :tag => :link
  end  

    
  def test_repository_path_sync
    User.current = users( :king )

    prj = Project.new(name: "Enterprise-SP0:GA")
    prj.update_from_xml( Xmlhash.parse(
      "<project name='Enterprise-SP0:GA'>
        <title/>
        <description/>
        <repository name='sp0_ga' />
      </project>"
      )
    )
    prj = Project.new(name: "Enterprise-SP0:Update")
    prj.update_from_xml( Xmlhash.parse(
      "<project name='Enterprise-SP0:Update'>
        <title/>
        <description/>
        <repository name='sp0_update' >
          <path project='Enterprise-SP0:GA' repository='sp0_ga' />
        </repository>
      </project>"
      )
    )
    prj = Project.new(name: "Enterprise-SP1:GA")
    prj.update_from_xml( Xmlhash.parse(
      "<project name='Enterprise-SP1:GA'>
        <title/>
        <description/>
        <repository name='sp1_ga' >
          <path project='Enterprise-SP0:GA' repository='sp0_ga' />
        </repository>
      </project>"
      )
    )
    prj = Project.new(name: "Enterprise-SP1:Update")
    prj.update_from_xml( Xmlhash.parse(
      "<project name='Enterprise-SP1:Update'>
        <title/>
        <description/>
        <repository name='sp1_update' >
          <path project='Enterprise-SP1:GA' repository='sp1_ga' />
          <path project='Enterprise-SP0:Update' repository='sp0_update' />
        </repository>
      </project>"
      )
    )
    # this is what the classic add_repository call is producing:
    prj = Project.new(name: "My:Branch")
    prj.update_from_xml( Xmlhash.parse(
      "<project name='My:Branch'>
        <title/>
        <description/>
        <repository name='my_branch_sp0_update' >
          <path project='Enterprise-SP0:Update' repository='sp0_update' />
        </repository>
        <repository name='my_branch_sp1_update' >
          <path project='Enterprise-SP1:Update' repository='sp1_update' />
        </repository>
      </project>"
      )
    )
    # however, this is not correct, because my:branch (or an incident)
    # is providing in this situation often a package in SP0:Update which
    # must be used for building the package in sp1 repo.
    # Since the order of adding the repositories is not fixed or can even
    # be extended with later calls, we need to sync this always after finishing a 
    # a setup of new branched packages with this sync function:
    xml = prj.to_axml
    assert_xml_tag xml, :tag => :repository, :attributes => {name: "my_branch_sp1_update"},
                        :children => { count: 1, :only => { :tag => :path } }

    assert_no_xml_tag xml, :tag => :path, :attributes => { project: "My:Branch", repository: "my_branch_sp0_update" }
    prj.sync_repository_pathes
    xml = prj.to_axml
    assert_xml_tag xml, :tag => :repository, :attributes => {name: "my_branch_sp1_update"},
                        :children => { count: 2, :only => { :tag => :path } }
    assert_xml_tag xml, :tag => :repository, :attributes => {name: "my_branch_sp0_update"},
                        :children => { count: 1, :only => { :tag => :path } } # untouched
    assert_xml_tag xml, :tag => :path, :attributes => { project: "My:Branch", repository: "my_branch_sp0_update" }

    # must not change again anything
    prj.sync_repository_pathes
    assert_equal xml, prj.to_axml
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
  
  test 'invalid names' do
    # no ::
    assert !Project.valid_name?('home:M0ses:raspi::qtdesktop')
    assert !Project.valid_name?(10)
    assert !Project.valid_name?('')
    assert !Project.valid_name?('_foobar')
    assert !Project.valid_name?("4" * 250)
  end

  test 'valid name' do
    assert Project.valid_name?("foobar")
    assert Project.valid_name?("Foobar_")
    assert Project.valid_name?("foo1234")
    assert Project.valid_name?("4" * 200)
  end

  test 'exists_by_name' do
    User.current = users( :Iggy )

    assert Project.exists_by_name('home:Iggy')
    assert Project.exists_by_name('RemoteInstance')
    assert Project.exists_by_name('RemoteInstance:NoMatterIfThisProjectExistsOrNot')
    assert Project.exists_by_name('RemoteInstance:NoMatter:IfThisProjectExistsOrNot')
    assert_not Project.exists_by_name('NonExistingProject')
    assert_not Project.exists_by_name('Some:NonExistingProject')
    assert_not Project.exists_by_name('HiddenProject')
    assert_not Project.exists_by_name('HiddenRemoteInstance')
  end
end

