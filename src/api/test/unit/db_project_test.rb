require File.dirname(__FILE__) + '/../test_helper'

class DbProjectTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @project = DbProject.find( 502 )
  end
  
    
  def test_flags_to_axml
    #check precondition
    assert_equal 2, @project.type_flags('build').size
    assert_equal 2, @project.type_flags('publish').size
    
    xml_string = @project.to_axml
    #puts xml_string
    
    #check the results
    xml = REXML::Document.new(xml_string)
    assert_equal 1, xml.root.get_elements("/project/build").size
    assert_equal 2, xml.root.get_elements("/project/build/*").size
    
    assert_equal 1, xml.root.get_elements("/project/publish").size
    assert_equal 2, xml.root.get_elements("/project/publish/*").size    
  end
  
  
  def test_add_new_flags_from_xml
    
    #precondition check
    @project.flags.destroy_all
    @project.reload
    assert_equal 0, @project.flags.size
    
    #project is given as axml
    axml = ActiveXML::Base.new(
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
    
    ['build', 'publish', 'debuginfo'].each do |flagtype|
      @project.update_flags(axml, flagtype)
    end
      
    @project.reload
    
    #check results
    assert_equal 1, @project.type_flags('build').size
    assert_equal 'disable', @project.type_flags('build')[0].status
    assert_equal '10.2', @project.type_flags('build')[0].repo
    assert_equal 'i586', @project.type_flags('build')[0].architecture.name
    assert_equal 1, @project.type_flags('build')[0].position
    assert_nil @project.type_flags('build')[0].db_package    
    assert_equal 'home:Iggy', @project.type_flags('build')[0].db_project.name
    
    assert_equal 1, @project.type_flags('publish').size
    assert_equal 'enable', @project.type_flags('publish')[0].status
    assert_equal '10.2', @project.type_flags('publish')[0].repo
    assert_equal 'x86_64', @project.type_flags('publish')[0].architecture.name
    assert_equal 2, @project.type_flags('publish')[0].position
    assert_nil @project.type_flags('publish')[0].db_package    
    assert_equal 'home:Iggy', @project.type_flags('publish')[0].db_project.name  
    
    assert_equal 1, @project.type_flags('debuginfo').size
    assert_equal 'disable', @project.type_flags('debuginfo')[0].status
    assert_equal '10.0', @project.type_flags('debuginfo')[0].repo
    assert_equal 'i586', @project.type_flags('debuginfo')[0].architecture.name
    assert_equal 3, @project.type_flags('debuginfo')[0].position
    assert_nil @project.type_flags('debuginfo')[0].db_package    
    assert_equal 'home:Iggy', @project.type_flags('debuginfo')[0].db_project.name      
    
  end
  
  
  def test_delete_flags_through_xml
    #check precondition
    assert_equal 2, @project.type_flags('build').size
    assert_equal 2, @project.type_flags('publish').size
    
    #project is given as axml
    axml = ActiveXML::Base.new(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description></description> 
      </project>"
      )    
    
    #first update build-flags, should only delete build-flags
    @project.update_flags(axml, 'build')
    assert_equal 0, @project.type_flags('build').size
        
    #second update publish-flags, should delete publish-flags    
    @project.update_flags(axml, 'publish')
    assert_equal 0, @project.type_flags('publish').size
    
  end
  
  
  def test_flag_type_mismatch
    #check precondition
    assert_equal 2, @project.type_flags('build').size    
  
    axml = ActiveXML::Base.new(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description></description>
        <build>
          <enable repository='10.2' arch='i586'/>
        </build>      
        <url></url>
        <disable repository='10.0' arch='i586'/>
      </project>"
      )    
  
    assert_equal 2, @project.type_flags('build').size  
  end
  
  
  def test_store_axml
    original = @project.to_axml

    #project is given as axml
    axml = ActiveXML::Base.new(
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
      
    @project.store_axml(axml)
    
    assert_equal 0, @project.type_flags('build').size
    assert_equal 1, @project.type_flags('debuginfo').size        

    @project.store_axml(ActiveXML::Base.new(original))
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


#TODO delete
#  def test_update_flags
#    
#    puts "build flag count:\t", @project.type_flags('build').size, "\n" 
#        put_flags(@project.type_flags('build'))
#        
#        puts "\n adding new flag ................."
#        f= BuildFlag.new(:status => 'disable', :repo => '10.2')
#        @project.type_flags('build') << f
#        f.move_to_top    
#        @project.reload
#        
#        f =  BuildFlag.new(:status => 'enabled')
#        @project.type_flags('build') << f
#        f.move_to_top
#        @project.reload
#        put_flags(@project.type_flags('build'))
#        
#        puts "\n to axml ........................."    
#        axml = ActiveXML::Base.new(@project.to_axml.to_s)
#        puts axml.data.to_s
#        
#        puts "\n update flags with the axml ......"
#        ret =  @project.update_flags(:project => axml, :flagtype => "build")
#        #logger.debug "TEESSSTTT"
#        @project.reload
#        put_flags @project.type_flags('build')
#        
##        put_flags(ret)
##        puts ret.size
##        
##        puts "\n get this result as axml ........."
##        puts ".........done"
##        @project.reload
##        axml = ActiveXML::Base.new(@project.to_axml.to_s)
##        
##        puts "\n remove all enabled flags from axml "
##        3.times do 
##          axml.data.root.delete_element "build/enabled"
##        end
##        puts axml.data.to_s
##        
##        puts "\n update flags with the axml"
##        ret =  @project.update_flags(:project => axml, :flagtype => 'BuildFlag')
##        put_flags(ret)
##        puts ret.size         
#  end


