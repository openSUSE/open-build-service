require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class MaintenanceTests < ActionController::IntegrationTest 
  fixtures :all
  
  def test_create_maintenance_project
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user "tom", "thunder"
    
    put "/source/home:tom:maintenance/_meta", '<project name="home:tom:maintenance" > <title/> <description/> </project>'
    assert_response :success
    put "/source/home:tom:maintenance/_meta", '<project name="home:tom:maintenance" kind="maintenance" > <title/> <description/> </project>'
    assert_response :success
    delete "/source/home:tom:maintenance"
    assert_response :success

    put "/source/home:tom:maintenance/_meta", '<project name="home:tom:maintenance" kind="maintenance" > <title/> <description/> </project>'
    assert_response :success

    # cleanup
    delete "/source/home:tom:maintenance" 
    assert_response :success
  end

  def test_branch_package
    ActionController::IntegrationTest::reset_auth 
    prepare_request_with_user "tom", "thunder"

    # branch a package which does not exist in update project via project link
    post "/source/BaseDistro/pack1", :cmd => :branch
    assert_response :success
    # check source link
    get "/source/home:tom:branches:BaseDistro:Update/pack1/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "BaseDistro:Update"
    assert_equal ret.package, "pack1"
    assert_not_nil ret.baserev
    assert_not_nil ret.patches
    assert_not_nil ret.patches.branch

    # branch a package which does exist in update project and even have a devel package defined there
    post "/source/BaseDistro/pack2", :cmd => :branch
    assert_response :success
    # check source link
    get "/source/home:tom:branches:Devel:BaseDistro:Update/pack2/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "Devel:BaseDistro:Update"
    assert_equal ret.package, "pack2"
    assert_not_nil ret.baserev
    assert_not_nil ret.patches
    assert_not_nil ret.patches.branch

    # branch a package which does exist in update project and a stage project is defined via project wide devel project
    post "/source/BaseDistro/pack3", :cmd => :branch
    assert_response :success
    # check source link
    get "/source/home:tom:branches:Devel:BaseDistro:Update/pack3/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "Devel:BaseDistro:Update"
    assert_equal ret.package, "pack3"
    assert_not_nil ret.baserev
    assert_not_nil ret.patches
    assert_not_nil ret.patches.branch

    # branch a package which does not exist in update project, but update project is linked
    post "/source/BaseDistro2/pack2", :cmd => :branch
    assert_response :success
    # check source link
    get "/source/home:tom:branches:BaseDistro2:LinkedUpdateProject/pack2/_link"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.project, "BaseDistro2:LinkedUpdateProject"
    assert_equal ret.package, "pack2"

    # check if we can upload a link to a packge only exist via project link
    put "/source/home:tom:branches:BaseDistro2:LinkedUpdateProject/pack2/_link", @response.body
    assert_response :success

    #cleanup
    delete "/source/home:tom:branches:Devel:BaseDistro:Update"
    assert_response :success
  end

  def test_mbranch_and_maintenance_request
    prepare_request_with_user "king", "sunflower"
    put "/source/ServicePack/_meta", "<project name='ServicePack'><title/><description/><link project='kde4'/></project>"
    assert_response :success

    # setup maintained attributes
    prepare_request_with_user "maintenance_coord", "power"
    # an entire project
    post "/source/BaseDistro/_attribute", "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    # single packages
    post "/source/BaseDistro2/pack2/_attribute", "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post "/source/BaseDistro3/pack2/_attribute", "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post "/source/ServicePack/_attribute", "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success

    # search for maintained packages like osc is doing
    get "/search/package?match=%28%40name+%3D+%27pack2%27%29+and+%28project%2Fattribute%2F%40name%3D%27OBS%3AMaintained%27+or+attribute%2F%40name%3D%27OBS%3AMaintained%27%29"
    assert_response :success
    ret = ActiveXML::XMLNode.new @response.body
    assert_equal ret.package.each.count, 3
   
    # do the real mbranch for default maintained packages
    prepare_request_with_user "tom", "thunder"
    post "/source", :cmd => "branch", :package => "pack2", :noaccess => 1
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/_meta"
    assert_response :success
    assert_tag( :parent => {:tag => "access"}, :tag => "disable", :content => nil )
    delete "/source/home:tom:branches:OBS_Maintained:pack2"
    assert_response :success
    post "/source", :cmd => "branch", :package => "pack2"
    assert_response :success

    # validate result
    get "/source/home:tom:branches:OBS_Maintained:pack2"
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/_meta"
    assert_response :success
    assert_no_tag( :parent => {:tag => "access"}, :tag => "disable", :content => nil )
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2/_meta"
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro/_meta"
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2/_link"
    assert_response :success

    assert_tag :tag => "link", :attributes => { :project => "BaseDistro2:LinkedUpdateProject", :package => "pack2" }
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro/_link"
    assert_response :success
    assert_tag :tag => "link", :attributes => { :project => "BaseDistro:Update", :package => "pack2" }
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro/_history"
    assert_response :success
    assert_tag :tag => "comment", :content => "fetch updates from devel package"
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro3/_link"
    assert_response :success
    assert_tag :tag => "link", :attributes => { :project => "BaseDistro3", :package => "pack2" }
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.linked.BaseDistro3/_link"
    assert_response :success
    assert_no_tag :tag => "link", :attributes => { :project => "BaseDistro3", :package => "pack2" } # original wrong entry from source
    assert_tag :tag => "link", :attributes => { :package => "pack2.BaseDistro3" }

    # test branching another package set into same project
    post "/source", :cmd => "branch", :package => "pack1", :target_project => "home:tom:branches:OBS_Maintained:pack2"
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack1.BaseDistro"
    assert_response :success

    # test branching another package set into same project from same project
    post "/source", :cmd => "branch", :package => "pack3", :target_project => "home:tom:branches:OBS_Maintained:pack2"
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack3.BaseDistro"
    assert_response :success
    # test branching another package only reachable via project link into same project
    post "/source", :cmd => "branch", :package => "kdelibs", :target_project => "home:tom:branches:OBS_Maintained:pack2", :noaccess => 1
    assert_response 403
    assert_tag :tag => "status", :attributes => { :code => "create_project_no_permission" }
    post "/source", :cmd => "branch", :package => "kdelibs", :target_project => "home:tom:branches:OBS_Maintained:pack2"
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/kdelibs.ServicePack"
    assert_response :success
    get "/source/home:tom:branches:OBS_Maintained:pack2/kdelibs.ServicePack/_link"
    assert_response :success
    assert_tag :tag => "link", :attributes => { :project => "ServicePack", :package => "kdelibs" }

    # validate created project meta
    get "/source/home:tom:branches:OBS_Maintained:pack2/_meta"
    assert_response :success
    assert_tag :parent => { :tag => "build" }, :tag => "disable"

    assert_tag :parent => { :tag => "repository", :attributes => { :name => "BaseDistro2_BaseDistro2LinkedUpdateProject_repo" } }, 
               :tag => "path", :attributes => { :repository => "BaseDistro2LinkedUpdateProject_repo", :project => "BaseDistro2:LinkedUpdateProject" }
    assert_tag :parent => { :tag => "repository", :attributes => { :name => "BaseDistro2_BaseDistro2LinkedUpdateProject_repo" } }, 
               :tag => "arch", :content => "i586"

    assert_tag :parent => { :tag => "repository", :attributes => { :name => "BaseDistro_BaseDistroUpdateProject_repo" } }, 
               :tag => "path", :attributes => { :repository => "BaseDistroUpdateProject_repo", :project => "BaseDistro:Update" }

    assert_tag( :tag => "releasetarget", :attributes => { :project => "BaseDistro:Update", :repository => "BaseDistroUpdateProject_repo", :trigger => nil } )

    assert_tag( :tag => "releasetarget", :attributes => { :project => "BaseDistro2:LinkedUpdateProject", :repository => "BaseDistro2LinkedUpdateProject_repo", :trigger => nil } )

    # validate created package meta
    get "/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2/_meta"
    assert_response :success
    assert_tag :tag => "package", :attributes => { :name => "pack2.BaseDistro2", :project => "home:tom:branches:OBS_Maintained:pack2" }
    assert_tag :parent => { :tag => "build" }, :tag => "enable", :attributes => { :repository => "BaseDistro2_BaseDistro2LinkedUpdateProject_repo" }

    # and branch same package again and expect error
    post "/source", :cmd => "branch", :package => "pack1", :target_project => "home:tom:branches:OBS_Maintained:pack2"
    assert_response 400
    assert_tag :tag => "status", :attributes => { :code => "double_branch_package" }
    assert_match(/branch target package already exists:/, @response.body)

    # create patchinfo
    post "/source/BaseDistro?cmd=createpatchinfo&new_format=1"
    assert_response 403
    post "/source/home:tom:branches:OBS_Maintained:pack2?cmd=createpatchinfo&new_format=1"
    assert_response :success
    assert_tag( :tag => "data", :attributes => { :name => "targetpackage"}, :content => "patchinfo" )
    assert_tag( :tag => "data", :attributes => { :name => "targetproject"}, :content => "home:tom:branches:OBS_Maintained:pack2" )

    # create maintenance request
    # without specifing target, the default target must get found via attribute
    post "/request?cmd=create", '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" />
                                     <options>
                                       <sourceupdate>cleanup</sourceupdate>
                                     </options>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_tag( :tag => "target", :attributes => { :project => "My:Maintenance" } )
    node = ActiveXML::XMLNode.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)

    # validate that request is diffable (not broken)
    post "/request/#{id}?cmd=diff", nil
    assert_response :success

    # store data for later checks
    get "/source/home:tom:branches:OBS_Maintained:pack2/_meta"
    oprojectmeta = ActiveXML::XMLNode.new(@response.body)
    assert_response :success

    # accept request
    prepare_request_with_user "maintenance_coord", "power"
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    maintenanceProject=data.elements["/request/action/target"].attributes.get_attribute("project").to_s
    assert_not_equal maintenanceProject, "My:Maintenance"

    #validate cleanup
    get "/source/home:tom:branches:OBS_Maintained:pack2"
    assert_response 404

    # validate created project
    get "/source/#{maintenanceProject}/_meta"
    assert_response :success
    assert_tag( :parent => {:tag => "build"}, :tag => "disable", :content => nil )
    node = ActiveXML::XMLNode.new(@response.body)
    assert_not_nil node.repository.element_name
    # repository definition must be the same, except for the maintenance trigger
    node.each_repository do |r|
      assert_equal r.releasetarget.value("trigger"), "maintenance"
      r.releasetarget.delete_attribute("trigger")
    end
    assert_equal node.repository.dump_xml, oprojectmeta.repository.dump_xml
    assert_equal node.build.dump_xml, oprojectmeta.build.dump_xml

    get "/source/#{maintenanceProject}"
    assert_response :success
    assert_tag( :tag => "directory", :attributes => { :count => "8" } )

    get "/source/#{maintenanceProject}/pack2.BaseDistro2/_meta"
    assert_response :success
    assert_tag( :tag => "enable", :parent => {:tag => "build"}, :attributes => { :repository => "BaseDistro2_BaseDistro2LinkedUpdateProject_repo" } )
  end

  def test_create_maintenance_incident
    ActionController::IntegrationTest::reset_auth 
    post "/source/My:Maintenance", :cmd => "createmaintenanceincident"
    assert_response 401

    prepare_request_with_user "adrian", "so_alone"
    post "/source/My:Maintenance", :cmd => "createmaintenanceincident"
    assert_response 403

    prepare_request_with_user "maintenance_coord", "power"
    # create a public maintenance incident
    post "/source/My:Maintenance", :cmd => "createmaintenanceincident"
    assert_response :success
    assert_tag( :tag => "data", :attributes => { :name => "targetproject" } )
    data = REXML::Document.new(@response.body)
    maintenanceProject=data.elements["/status/data"].text
    incidentID=maintenanceProject.gsub( /^My:Maintenance:/, "" )
    get "/source/#{maintenanceProject}/_meta"
    assert_tag( :parent => {:tag => "build"}, :tag => "disable", :content => nil )
    assert_no_tag( :parent => {:tag => "access"}, :tag => "disable", :content => nil )
    assert_tag( :attributes => {:role => "maintainer", :userid => "maintenance_coord"}, :tag => "person", :content => nil )

    # create a maintenance incident under embargo
    post "/source/My:Maintenance?cmd=createmaintenanceincident&noaccess=1", nil
    assert_response :success
    assert_tag( :tag => "data", :attributes => { :name => "targetproject" } )
    data = REXML::Document.new(@response.body)
    maintenanceProject=data.elements["/status/data"].text
    incidentID=maintenanceProject.gsub( /^My:Maintenance:/, "" )
    get "/source/#{maintenanceProject}/_meta"
    assert_tag( :parent => {:tag => "build"}, :tag => "disable", :content => nil )
    assert_tag( :parent => {:tag => "access"}, :tag => "disable", :content => nil )
    assert_tag( :attributes => {:role => "maintainer", :userid => "maintenance_coord"}, :tag => "person", :content => nil )
  end

  def test_create_maintenance_project_and_release_packages
    prepare_request_with_user "maintenance_coord", "power"

    # setup 'My:Maintenance' as a maintenance project by fetching it's meta and set a type
    get "/source/My:Maintenance/_meta"
    assert_response :success
    maintenance_project_meta = REXML::Document.new(@response.body)
    maintenance_project_meta.elements['/project'].attributes['kind'] = 'maintenance'
    put "/source/My:Maintenance/_meta", maintenance_project_meta.to_s
    assert_response :success

    post "/source/My:Maintenance/_attribute", "<attributes><attribute namespace='OBS' name='MaintenanceIdTemplate'><value>My-%Y-%C</value></attribute></attributes>"
    assert_response :success

    # setup a maintained distro
    post "/source/BaseDistro2/_attribute", "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post "/source/BaseDistro2/_attribute", "<attributes><attribute namespace='OBS' name='UpdateProject' > <value>BaseDistro2:LinkedUpdateProject</value> </attribute> </attributes>"
    assert_response :success
    post "/source/BaseDistro3/_attribute", "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success

    # create a maintenance incident
    post "/source", :cmd => "createmaintenanceincident"
    assert_response :success
    assert_tag( :tag => "data", :attributes => { :name => "targetproject" } )
    data = REXML::Document.new(@response.body)
    maintenanceProject=data.elements["/status/data"].text
    incidentID=maintenanceProject.gsub( /^My:Maintenance:/, "" )
    get "/source/#{maintenanceProject}/_meta"
    assert_response :success
    assert_tag( :parent => {:tag => "build"}, :tag => "disable", :content => nil )
    assert_tag( :tag => "project", :attributes => { :name => maintenanceProject, :kind => "maintenance_incident" } )

    # submit packages via mbranch
    post "/source", :cmd => "branch", :package => "pack2", :target_project => maintenanceProject
    assert_response :success
    # correct branched ?
    get "/source/"+maintenanceProject+"/pack2.BaseDistro2/_link"
    assert_response :success
    assert_tag( :tag => "link", :attributes => { :project => "BaseDistro2:LinkedUpdateProject", :package => "pack2" } )
    get "/source/"+maintenanceProject+"/_meta"
    assert_response :success
    assert_tag( :tag => "path", :attributes => { :project => "BaseDistro2:LinkedUpdateProject", :repository => "BaseDistro2LinkedUpdateProject_repo" } )
    assert_tag( :tag => "releasetarget", :attributes => { :project => "BaseDistro2:LinkedUpdateProject", :repository => "BaseDistro2LinkedUpdateProject_repo", :trigger => "maintenance" } )

    # search will find this new and not yet processed incident now.
    get "/search/project", :match => '[repository/releasetarget/@trigger="maintenance"]'
    assert_response :success
    assert_tag :parent => { :tag => "collection" },  :tag => 'project', :attributes => { :name => maintenanceProject } 

    # Create patchinfo informations
    post "/source/#{maintenanceProject}?cmd=createpatchinfo&force=1&new_format=1"
    assert_response :success
    assert_tag( :tag => "data", :attributes => { :name => "targetpackage"}, :content => "patchinfo" )
    assert_tag( :tag => "data", :attributes => { :name => "targetproject"}, :content => maintenanceProject )
    get "/source/#{maintenanceProject}/patchinfo/_patchinfo"
    assert_response :success
    assert_tag( :tag => "patchinfo", :attributes => { :incident => incidentID } )
    # add required informations about the update
    pi = REXML::Document.new( @response.body )
    pi.elements["//category"].text = "security"
    pi.elements['/patchinfo'].add_element 'issue'
    pi.elements["//issue"].text = "Fix wrong set ,"
    pi.elements['//issue'].add_attribute REXML::Attribute.new('tracker', 'bnc')
    pi.elements['//issue'].add_attribute REXML::Attribute.new('id', '1042')
    pi.elements["//rating"].text = "low"
    issue2 = pi.elements['/patchinfo'].add_element 'issue'
    issue2.add_attribute REXML::Attribute.new('tracker', 'CVE')
    issue2.add_attribute REXML::Attribute.new('id', '0815')
    put "/source/#{maintenanceProject}/patchinfo/_patchinfo", pi.to_s
    assert_response :success
    get "/source/#{maintenanceProject}/patchinfo/_meta"
    assert_tag( :parent => {:tag => "build"}, :tag => "enable", :content => nil )

    # disable the packages we do not like to test here
#FIXME: the flag handling is currently broken
    post "/source/"+maintenanceProject+"/pack2.BaseDistro2?cmd=remove_flag&flag=build&repository='BaseDistro2_BaseDistro2LinkedUpdateProject_repo'"
    assert_response :success

    ### the backend is now building the packages, injecting results
    perlopts="-I#{RAILS_ROOT}/../backend -I#{RAILS_ROOT}/../backend/build"
    # run scheduler once to create job file. x86_64 scheduler gets no work
    IO.popen("cd #{RAILS_ROOT}/tmp/backend_config; exec perl #{perlopts} ./bs_sched --testmode x86_64") do |io|
       # just for waiting until scheduler finishes
       io.each {|line| line.strip.chomp unless line.blank? }
    end
    # run scheduler once to create job file
    IO.popen("cd #{RAILS_ROOT}/tmp/backend_config; exec perl #{perlopts} ./bs_sched --testmode i586") do |io|
       # just for waiting until scheduler finishes
       io.each {|line| line.strip.chomp unless line.blank? }
    end

    #### upload build result as a worker would do
    # find out about the triggered build job and write back dispatching data
    findMaintJob=IO.popen("find #{RAILS_ROOT}/tmp/backend_data/jobs/x86_64/ -name #{maintenanceProject}::BaseDistro2_BaseDistro2LinkedUpdateProject_repo::pack2.BaseDistro2-*")
    maintJob=findMaintJob.readlines.first.chomp
    jobid=""
    IO.popen("md5sum #{maintJob}|cut -d' ' -f 1") do |io|
       jobid = io.readlines.first.chomp
    end
    f = File.open("#{maintJob}:status", 'w')
    f.write( "<jobstatus code=\"building\"> <jobid>#{jobid}</jobid> <workerid>simulated</workerid> <hostarch>x86_64</hostarch> </jobstatus>" )
    f.close
    # for x86_64
    system("cd #{RAILS_ROOT}/test/fixtures/backend/binary/; exec find . -name '*x86_64.rpm' -o -name '*src.rpm' -o -name logfile | cpio -H newc -o | curl -s -X POST -T - 'http://localhost:3201/putjob?arch=x86_64&code=success&job=#{maintJob.gsub(/.*\//, '')}&jobid=#{jobid}'")
    system("echo \"46d4408d324ac84a93aef39181b6a60c  pack2.BaseDistro2\" > #{maintJob}:dir/meta")
    # run scheduler again to collect result
    IO.popen("cd #{RAILS_ROOT}/tmp/backend_config; exec perl #{perlopts} ./bs_sched --testmode x86_64") do |io|
       # just for waiting until scheduler finishes
       io.each {|line| line.strip.chomp unless line.blank? }
    end
    # find out about the triggered build job and write back dispatching data
    findMaintJob=IO.popen("find #{RAILS_ROOT}/tmp/backend_data/jobs/i586/ -name #{maintenanceProject}::BaseDistro2_BaseDistro2LinkedUpdateProject_repo::pack2.BaseDistro2-*")
    maintJob=findMaintJob.readlines.first.chomp
    jobid=""
    IO.popen("md5sum #{maintJob}|cut -d' ' -f 1") do |io|
       jobid = io.readlines.first.chomp
    end
    f = File.open("#{maintJob}:status", 'w')
    f.write( "<jobstatus code=\"building\"> <jobid>#{jobid}</jobid> </jobstatus>" )
    f.close
    # for i586
    system("cd #{RAILS_ROOT}/test/fixtures/backend/binary/; exec find . -name '*i586.rpm' -o -name '*src.rpm' -o -name logfile | cpio -H newc -o | curl -s -X POST -T - 'http://localhost:3201/putjob?arch=i586&code=success&job=#{maintJob.gsub(/.*\//, '')}&jobid=#{jobid}'")
    system("echo \"46d4408d324ac84a93aef39181b6a60c  pack2.BaseDistro2\" > #{maintJob}:dir/meta")
    # run scheduler again to collect result
    IO.popen("cd #{RAILS_ROOT}/tmp/backend_config; exec perl #{perlopts} ./bs_sched --testmode i586") do |io|
       # just for waiting until scheduler finishes
       io.each {|line| line.strip.chomp unless line.blank? }
    end

    # check updateinfo
    get "/build/#{maintenanceProject}/BaseDistro2_BaseDistro2LinkedUpdateProject_repo/i586/patchinfo/updateinfo.xml"
    assert_response :success
    assert_tag :parent => { :tag => "update", :attributes => { :from => "maintenance_coord", :status => "stable",  :type => "security", :version => "1" } }, :tag => "id", :content => nil
    assert_tag :tag => "reference", :attributes => { :href => "https://bugzilla.novell.com/show_bug.cgi?id=1042", :id => "1042",  :type => "bugzilla" } 
    assert_tag :tag => "reference", :attributes => { :href => "http://cve.mitre.org/cgi-bin/cvename.cgi?name=0815", :id => "0815",  :type => "cve" } 
    assert_no_tag :tag => "reference", :attributes => { :href => "https://bugzilla.novell.com/show_bug.cgi?id=" } 
    assert_no_tag :tag => "reference", :attributes => { :id => "" }

    # create release request
    post "/request?cmd=create", '<request>
                                   <action type="maintenance_release">
                                     <source project="' + maintenanceProject + '" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_no_tag( :tag => "target", :attributes => { :project => "BaseDistro2:LinkedUpdateProject", :package => "pack2" } )
    assert_no_tag( :tag => "target", :attributes => { :project => "BaseDistro3", :package => "pack2" } )
    assert_no_tag( :tag => "target", :attributes => { :project => maintenanceProject } )
    assert_tag( :tag => "target", :attributes => { :project => "BaseDistro2:LinkedUpdateProject", :package => "pack2." + incidentID } )
    assert_tag( :tag => "target", :attributes => { :project => "BaseDistro3", :package => "pack2." + incidentID } )
    assert_tag( :tag => "target", :attributes => { :project => "BaseDistro2:LinkedUpdateProject", :package => "patchinfo." + incidentID } )
    assert_tag( :tag => "target", :attributes => { :project => "BaseDistro3", :package => "patchinfo." + incidentID } )
    assert_tag( :tag => "review", :attributes => { :by_group => "test_group" } )
    node = ActiveXML::XMLNode.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)

    # validate that request is diffable (not broken)
    post "/request/#{reqid}?cmd=diff", nil
    assert_response :success

    # source packages got locked
    [ "pack2.BaseDistro2", "pack2.BaseDistro3", "patchinfo" ].each do |pack|
      get "/source/#{maintenanceProject}/#{pack}/_meta"
      assert_response :success
      assert_tag( :parent => { :tag => "lock" }, :tag => "enable" )
    end

    # approve review
    prepare_request_with_user "king", "sunflower"
    post "/request/#{reqid}?cmd=changereviewstate&newstate=accepted&by_group=test_group&comment=blahfasel"
    assert_response :success

    # release packages
    post "/request/#{reqid}?cmd=changestate&newstate=accepted"
    assert_response :success
    IO.popen("cd #{RAILS_ROOT}/tmp/backend_config; exec perl #{perlopts} ./bs_sched --testmode i586") do |io|
       # just for waiting until scheduler finishes
       io.each {|line| line.strip.chomp unless line.blank? }
    end

    # validate result
    get "/source/BaseDistro2:LinkedUpdateProject/pack2/_link"
    assert_response :success
    assert_tag :tag => "link", :attributes => { :project => nil, :package => "pack2.#{incidentID}" }
    get "/source/BaseDistro2:LinkedUpdateProject/pack2.#{incidentID}/_link"
    assert_response 404
    get "/source/BaseDistro2:LinkedUpdateProject/patchinfo"
    assert_response 404
    get "/source/BaseDistro2:LinkedUpdateProject/patchinfo.#{incidentID}"
    assert_response :success
    get "/source/BaseDistro2:LinkedUpdateProject/patchinfo.#{incidentID}/_patchinfo"
    assert_response :success
    assert_tag :tag => "patchinfo", :attributes => { :incident => incidentID }
    assert_tag :tag => "packager", :content => "maintenance_coord"
    get "/build/BaseDistro2:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586"
    assert_response :success
    get "/build/BaseDistro2:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/patchinfo.#{incidentID}"
    assert_response :success
    assert_tag :tag => "binary", :attributes => { :filename => "updateinfo.xml" }
    get "/build/BaseDistro2:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/patchinfo.#{incidentID}/updateinfo.xml"
    assert_response :success
    # check for changed updateinfoid 
    assert_tag :parent => { :tag => "update", :attributes => { :from => "maintenance_coord", :status => "stable",  :type => "security", :version => "1" } }, :tag => "id", :content => "My-#{Time.now.utc.year.to_s}-1"

    # search will find this incident not anymore
    get "/search/project", :match => '[repository/releasetarget/@trigger="maintenance"]'
    assert_response :success
    assert_no_tag :parent => { :tag => "collection" },  :tag => 'project', :attributes => { :name => maintenanceProject } 

    #cleanup
    delete "/source/#{maintenanceProject}"
    assert_response :success
  end

  def test_create_invalid_release_request
    prepare_request_with_user "tom", "thunder"
    # branch a package with simple branch command (not mbranch)
    post "/source/BaseDistro/pack1", :cmd => :branch
    assert_response :success
    # check source link
    get "/source/home:tom:branches:BaseDistro:Update/pack1/_link"
    assert_response :success

    prepare_request_with_user "maintenance_coord", "power"
    rq = '<request>
           <action type="maintenance_release">
             <source project="home:tom:branches:BaseDistro:Update" />
           </action>
           <state name="new" />
         </request>'
    post "/request?cmd=create", rq
    assert_response 400
    assert_tag :tag => "status", :attributes => { :code => "missing_patchinfo" }

    # add required informations about the update
    prepare_request_with_user "tom", "thunder"
    post "/source/home:tom:branches:BaseDistro:Update?cmd=createpatchinfo&force=1&new_format=1"
    assert_response :success

    prepare_request_with_user "maintenance_coord", "power"
    post "/request?cmd=create", rq
    assert_response 404
    assert_tag :tag => "status", :attributes => { :code => "build_not_finished" }

    # ignore build state
    prepare_request_with_user "maintenance_coord", "power"
    post "/request?cmd=create&ignore_build_state=1", rq
    assert_response 404
    assert_tag :tag => "status", :attributes => { :code => "repository_without_releasetarget" }

    # add a release target and remove architecture
    prepare_request_with_user "tom", "thunder"
    get "/source/home:tom:branches:BaseDistro:Update/_meta"
    assert_response :success
    pi = REXML::Document.new( @response.body )
    pi.elements['//repository'].add_element 'releasetarget'
    pi.elements['//releasetarget'].add_attribute REXML::Attribute.new('project', 'BaseDistro')
    pi.elements['//releasetarget'].add_attribute REXML::Attribute.new('repository', 'BaseDistro_repo')
    pi.elements['//repository'].delete_element 'arch'
    put "/source/home:tom:branches:BaseDistro:Update/_meta", pi.to_s
    assert_response :success

    prepare_request_with_user "maintenance_coord", "power"
    post "/request?cmd=create&ignore_build_state=1", rq
    assert_response 404
    assert_tag :tag => "status", :attributes => { :code => "repository_without_architecture" }

    # add a wrong architecture
    prepare_request_with_user "tom", "thunder"
    pi.elements['//repository'].add_element 'arch'
    pi.elements['//arch'].text = "ppc"
    put "/source/home:tom:branches:BaseDistro:Update/_meta", pi.to_s
    assert_response :success

    prepare_request_with_user "maintenance_coord", "power"
    post "/request?cmd=create&ignore_build_state=1", rq
    assert_response 404
    assert_tag :tag => "status", :attributes => { :code => "architecture_order_missmatch" }

    # cleanup
    prepare_request_with_user "tom", "thunder"
    delete "/source/home:tom:branches:BaseDistro:Update"
    assert_response :success
  end

  def test_try_to_release_without_permissions_binary_permissions
    prepare_request_with_user "tom", "thunder"
    # create project
    put "/source/home:tom:test/_meta", "<project name='home:tom:test'> <title/> <description/> 
                                         <repository name='dummy'>
                                           <releasetarget project='BaseDistro' repository='BaseDistro_repo' trigger='maintenance' />
                                           <arch>i586</arch>
                                          </repository>
                                        </project>"
    assert_response :success
    put "/source/home:tom:test/pack/_meta", "<package name='pack'> <title/> <description/> </package>"
    assert_response :success

    # create release request
    post "/request?cmd=create", '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:test" package="pack" />
                                     <target project="home:tom:test" package="pack" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)

    # fail ...
    post "/request/#{reqid}?cmd=changestate&newstate=accepted"
    assert_response 403
    assert_tag :tag => "status", :attributes => { :code => "release_target_no_permission" }

    # cleanup 
    delete "/source/home:tom:test"
    assert_response :success
  end

  def test_try_to_release_without_permissions_source_permissions
    prepare_request_with_user "tom", "thunder"
    # create project
    put "/source/home:tom:test/_meta", "<project name='home:tom:test'> <title/> <description/> </project>" 
    assert_response :success
    put "/source/home:tom:test/pack/_meta", "<package name='pack'> <title/> <description/> </package>"
    assert_response :success

    # create release request
    post "/request?cmd=create", '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:test" package="pack" />
                                     <target project="BaseDistro" package="pack" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::XMLNode.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)

    # fail ...
    post "/request/#{reqid}?cmd=changestate&newstate=accepted"
    assert_response 403
    assert_tag :tag => "status", :attributes => { :code => "post_request_no_permission" }

    # cleanup 
    delete "/source/home:tom:test"
    assert_response :success
  end

  def test_copy_project_for_release
    # as user
    prepare_request_with_user "tom", "thunder"
    post "/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro"
    assert_response 403
    post "/source/home:tom:CopyOfBaseDistro?cmd=copy&oproject=BaseDistro"
    assert_response :success
    delete "/source/home:tom:CopyOfBaseDistro"
    assert_response :success

    # as admin
    prepare_request_with_user "king", "sunflower"
    post "/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&nodelay=1"
    assert_response :success
    get "/source/CopyOfBaseDistro/_meta"
    assert_response :success
    get "/source/BaseDistro"
    assert_response :success
    opackages = ActiveXML::XMLNode.new(@response.body)
    get "/source/CopyOfBaseDistro"
    assert_response :success
    packages = ActiveXML::XMLNode.new(@response.body)
    assert_equal opackages.dump_xml, packages.dump_xml

    # compare revisions
    get "/source/BaseDistro/pack2/_history"
    assert_response :success
    history = ActiveXML::XMLNode.new(@response.body)
    srcmd5 = history.each_revision.last.srcmd5.text
    version = history.each_revision.last.version.text
    time = history.each_revision.last.time.text
    vrev = history.each_revision.last.vrev
    assert_not_nil srcmd5
    get "/source/CopyOfBaseDistro/pack2/_history"
    assert_response :success
    copyhistory = ActiveXML::XMLNode.new(@response.body)
    copysrcmd5 = copyhistory.each_revision.last.srcmd5.text
    copyversion = copyhistory.each_revision.last.version.text
    copytime = copyhistory.each_revision.last.time.text
    copyrev = copyhistory.each_revision.last.rev
    copyvrev = copyhistory.each_revision.last.vrev
    assert_equal srcmd5, copysrcmd5
    assert_equal vrev.to_i, copyvrev.to_i - 1  #the copy gets always an additional commit
    assert_equal version, copyversion
    assert_not_equal time, copytime
    assert_equal copyhistory.each_revision.last.user.text, "king"

    delete "/source/CopyOfBaseDistro"
    assert_response :success
  end

  def test_copy_project_for_release_with_history_and_binaries
    prepare_request_with_user "tom", "thunder"
    post "/source/home:tom:CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&withhistory=1"
    assert_response 403
    assert_tag :tag => "status", :attributes => { :code => "project_copy_no_permission" }
    prepare_request_with_user "tom", "thunder"
    post "/source/home:tom:CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&withbinaries=1"
    assert_response 403
    assert_tag :tag => "status", :attributes => { :code => "project_copy_no_permission" }

    # as admin
    prepare_request_with_user "king", "sunflower"
    post "/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&withhistory=1&withbinaries=1&nodelay=1"
    assert_response :success
    get "/source/CopyOfBaseDistro/_meta"
    assert_response :success
    get "/source/BaseDistro"
    assert_response :success
    opackages = ActiveXML::XMLNode.new(@response.body)
    get "/source/CopyOfBaseDistro"
    assert_response :success
    packages = ActiveXML::XMLNode.new(@response.body)
    assert_equal opackages.to_s, packages.to_s

    # compare revisions
    get "/source/BaseDistro/pack2/_history"
    assert_response :success
    history = ActiveXML::XMLNode.new(@response.body)
    srcmd5 = history.each_revision.last.srcmd5.text
    version = history.each_revision.last.version.text
    time = history.each_revision.last.time.text
    vrev = history.each_revision.last.vrev
    assert_not_nil srcmd5
    get "/source/CopyOfBaseDistro/pack2/_history"
    assert_response :success
    copyhistory = ActiveXML::XMLNode.new(@response.body)
    copysrcmd5 = copyhistory.each_revision.last.srcmd5.text
    copyversion = copyhistory.each_revision.last.version.text
    copytime = copyhistory.each_revision.last.time.text
    copyrev = copyhistory.each_revision.last.rev
    copyvrev = copyhistory.each_revision.last.vrev
    assert_equal srcmd5, copysrcmd5
    assert_equal vrev.to_i, copyvrev.to_i - 1  #the copy gets always an additional commit
    assert_equal version, copyversion
    assert_not_equal time, copytime
    assert_equal copyhistory.each_revision.last.user.text, "king"

    # compare binaries
    get "/build/BaseDistro/BaseDistro_repo/i586/pack2"
    assert_response :success
    assert_tag :tag => "binary", :attributes => { :filename => "package-1.0-1.i586.rpm" }

    delete "/source/CopyOfBaseDistro"
    assert_response :success
  end

end
