require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'source_controller'

class MaintenanceTests < ActionDispatch::IntegrationTest 
  fixtures :all
  
  def setup
    super
    wait_for_scheduler_start
    stub_request(:post, 'http://bugzilla.novell.com/xmlrpc.cgi').to_timeout
  end

  teardown do
    Timecop.return
  end

  def test_create_maintenance_project
    login_tom
    
    put '/source/home:tom:maintenance/_meta', '<project name="home:tom:maintenance" > <title/> <description/> </project>'
    assert_response :success
    put '/source/home:tom:maintenance/_meta', '<project name="home:tom:maintenance" kind="maintenance" > <title/> <description/> </project>'
    assert_response :success
    delete '/source/home:tom:maintenance'
    assert_response :success

    # need write permission in maintained project...
    put '/source/home:tom:maintenance/_meta', '<project name="home:tom:maintenance" kind="maintenance" > <title/> <description/> <maintenance><maintains project="BaseDistro"/></maintenance> </project>'
    assert_response 403
    assert_xml_tag :tag => 'summary', :content => "No write access to maintained project BaseDistro"

    # create one ...
    put '/source/home:tom:maintenance/_meta', '<project name="home:tom:maintenance" kind="maintenance" > <title/> <description/> <maintenance><maintains project="home:tom"/></maintenance> </project>'
    assert_response :success
    get '/source/home:tom:maintenance/_meta'
    assert_response :success
    assert_xml_tag :tag => 'maintains', :attributes => { project: 'home:tom' }

    get '/search/project', :match => '[maintenance/maintains/@project="home:tom"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { count: 1 }
    assert_xml_tag :tag => 'maintains', :attributes => { project: 'home:tom' }

    # cleanup
    delete '/source/home:tom:maintenance'
    assert_response :success

    # search does not find a maintained project anymore
    get '/search/project', :match => '[maintenance/maintains/@project="home:tom"]'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { count: 0 }
  end

  def assert_project(prj)
    ret = Xmlhash.parse @response.body
    assert_equal prj, ret['project']
    assert_nil ret['package']
    assert_not_nil ret['baserev']
    assert_not_nil ret['patches']
    assert_not_nil ret['patches']['branch']
  end

  def test_branch_package
    login_tom

    # branch a package which does not exist in update project via project link
    post '/source/BaseDistro/pack1', :cmd => :branch
    assert_response :success
    # check source link
    get '/source/home:tom:branches:BaseDistro:Update/pack1/_link'
    assert_response :success
    assert_project 'BaseDistro:Update'

    # branch a package which does exist in update project and even have a devel package defined there
    post '/source/BaseDistro/pack2', :cmd => :branch
    assert_response :success
    # check source link
    get '/source/home:tom:branches:Devel:BaseDistro:Update/pack2/_link'
    assert_response :success
    ret = Xmlhash.parse @response.body
    assert_project 'Devel:BaseDistro:Update'

    # branch a package which does exist in update project and a stage project is defined via project wide devel project
    post '/source/BaseDistro/pack3', :cmd => :branch
    assert_response :success
    # check source link
    get '/source/home:tom:branches:Devel:BaseDistro:Update/pack3/_link'
    assert_response :success
    assert_project 'Devel:BaseDistro:Update'

    # branch a package which does not exist in update project, but update project is linked
    post '/source/BaseDistro2.0/pack2', :cmd => :branch
    assert_response :success
    # check source link
    get '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_link'
    assert_response :success
    ret = Xmlhash.parse @response.body
    assert_equal 'BaseDistro2.0:LinkedUpdateProject', ret['project']
    assert_nil ret['package']

    # check if we can upload a link to a packge only exist via project link
    put '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_link', @response.body
    assert_response :success

    #cleanup
    delete '/source/home:tom:branches:Devel:BaseDistro:Update'
    assert_response :success
  end

  def test_maintenance_request_from_foreign_project
    login_king
    # special kdelibs
    put '/source/BaseDistro2.0:LinkedUpdateProject/kdelibs/_meta', "<package name='kdelibs'><title/><description/></package>"
    assert_response :success
    put '/source/BaseDistro2.0:LinkedUpdateProject/kdelibs/empty', 'NOOP'
    assert_response :success

    login_tom
    # create maintenance request for one package from a unrelated project
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="BaseDistro2.0:LinkedUpdateProject" />
                                   </action>
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag( :tag => 'target', :attributes => { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id1 = node.value(:id)

    # validate that request is diffable (not broken)
    post "/request/#{id1}?cmd=diff&view=xml", nil
    assert_response :success
    # the diffed packages
    assert_xml_tag( :tag => 'old', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kdelibs' } )
    assert_xml_tag( :tag => 'new', :attributes => { project: 'kde4', package: 'kdelibs' } )
    # the expected file transfer
    assert_xml_tag( :tag => 'source', :attributes => { project: 'kde4', package: 'kdelibs' } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' } )
    # diff contains the critical lines
    assert_match( /^\-NOOP/, @response.body )
    assert_match( /^\+argl/, @response.body )

    # accept request
    prepare_request_with_user 'maintenance_coord', 'power'
    post "/request/#{id1}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success

    get "/request/#{id1}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    incidentProject=data.elements['/request/action/target'].attributes.get_attribute('project').to_s

    get "/source/#{incidentProject}/kdelibs.BaseDistro2.0_LinkedUpdateProject"
    assert_response :success
    assert_xml_tag( :tag => 'linkinfo', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kdelibs' } )

    # no patchinfo was part in source project, got it created ?
    get "/source/#{incidentProject}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag :tag => 'packager', :content => 'tom'
    assert_xml_tag( :tag => 'patchinfo', :attributes => { incident: '0' } )
    assert_xml_tag :tag => 'description', :content => 'To fix my bug'

    # again but find update project automatically and use a linked package
    login_tom
    post '/source/kde4/kdelibs', :cmd => :branch, :ignoredevel => 1
    assert_response :success
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="BaseDistro2.0" />
                                   </action>
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    # update project extended ?
    assert_xml_tag( :tag => 'target', :attributes => { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id2 = node.value(:id)

    # validate that request is diffable (not broken)
    post "/request/#{id2}?cmd=diff&view=xml", nil
    assert_response :success
    # the diffed packages
    assert_xml_tag( :tag => 'old', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kdelibs' } )
    assert_xml_tag( :tag => 'new', :attributes => { project: 'home:tom:branches:kde4', package: 'kdelibs' } )
    # the expected file transfer
    assert_xml_tag( :tag => 'source', :attributes => { project: 'home:tom:branches:kde4', package: 'kdelibs' } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' } )
    # diff contains the critical lines
    assert_match( /^\-NOOP/, @response.body )
    assert_match( /^\+argl/, @response.body )

    # accept request
    prepare_request_with_user 'maintenance_coord', 'power'
    post "/request/#{id2}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success

    get "/request/#{id2}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    incidentProject=data.elements['/request/action/target'].attributes.get_attribute('project').to_s

    get "/source/#{incidentProject}/kdelibs.BaseDistro2.0_LinkedUpdateProject"
    assert_response :success
    assert_xml_tag( :tag => 'linkinfo', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kdelibs' } )

    # no patchinfo was part in source project, got it created ?
    get "/source/#{incidentProject}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag :tag => 'packager', :content => 'tom'
    assert_xml_tag :tag => 'description', :content => 'To fix my bug'
    assert_xml_tag( :tag => 'patchinfo', :attributes => { incident: '1' } )

    # reopen ...
    prepare_request_with_user 'maintenance_coord', 'power'
    post "/request/#{id2}?cmd=changestate&newstate=new"
    assert_response 403

    # cleanup
    login_king
#    delete '/source/BaseDistro2.0:LinkedUpdateProject/kdelibs'
#    assert_response :success
    delete '/source/home:tom:branches:kde4'
    assert_response :success
  end

  def test_mbranch_and_maintenance_per_package_request
    login_king
    put '/source/BaseDistro3/pack2/file', 'NOOP'
    assert_response :success
    # setup maintained attributes
    prepare_request_with_user 'maintenance_coord', 'power'
    # single packages
    post '/source/BaseDistro2.0/pack2/_attribute', "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post '/source/BaseDistro3/pack2/_attribute', "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success

    # search for maintained packages like osc is doing
    get '/search/package?match=%28%40name+%3D+%27pack2%27%29+and+%28project%2Fattribute%2F%40name%3D%27OBS%3AMaintained%27+or+attribute%2F%40name%3D%27OBS%3AMaintained%27%29'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { count: 2 }
   
    # do the real mbranch for default maintained packages
    login_tom
    post '/source', :cmd => 'branch', :package => 'pack2'
    assert_response :success

    # validate result is done in project wide test case

    # do some file changes
    put '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject/new_file', 'new_content_0815'
    assert_response :success
    put '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro3/file', 'new_content_2137'
    assert_response :success

    # create maintenance request for one package
    # without specifing target, the default target must get found via attribute
    post '/request?cmd=create&addrevision=1', '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.BaseDistro3" />
                                     <options>
                                       <sourceupdate>cleanup</sourceupdate>
                                     </options>
                                   </action>
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_no_xml_tag( :tag => 'source', :attributes => { rev: nil } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'My:Maintenance' } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id1 = node.value(:id)

    # validate that request is diffable (not broken)
    post "/request/#{id1}?cmd=diff&view=xml", nil
    assert_response :success
    # the diffed packages
    assert_xml_tag( :tag => 'old', :attributes => { project: 'BaseDistro3', package: 'pack2', srcmd5: 'e4b3b98ad76a0fbcdbf888694842c149' } )
    assert_xml_tag( :tag => 'new', :attributes => { project: 'home:tom:branches:OBS_Maintained:pack2', package: 'pack2.BaseDistro3', rev: 'a645178fa01c5efa76cfba0a1e94f6ba', srcmd5: 'a645178fa01c5efa76cfba0a1e94f6ba' })
    # the diffed files
    assert_xml_tag( :tag => 'old', :attributes => { name: 'file', md5: '722d122e81cbbe543bd5520bb8678c0e', size: '4' },
                    :parent => { tag: 'file', attributes: { state: 'changed' } } )
    assert_xml_tag( :tag => 'new', :attributes => { name: 'file', md5: '6c7c49c0d7106a1198fb8f1b3523c971', size: '16' },
                    :parent => { tag: 'file', attributes: { state: 'changed' } } )
    # the expected file transfer
    assert_xml_tag( :tag => 'source', :attributes => { project: 'home:tom:branches:OBS_Maintained:pack2', package: 'pack2.BaseDistro3', rev: 'a645178fa01c5efa76cfba0a1e94f6ba' } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'My:Maintenance', releaseproject: 'BaseDistro3' } )
    # diff contains the critical lines
    assert_match( /^\-NOOP/, @response.body )
    assert_match( /^\+new_content_2137/, @response.body )

    # search as used by osc sees it
    get '/search/request', :match => 'action/@type="maintenance_incident" and (state/@name="new" or state/@name="review") and starts-with(action/target/@project, "My:Maintenance")'
    assert_response :success
    assert_xml_tag :parent => { tag: 'collection' }, :tag => 'request', :attributes => { id: id1 }

    # accept request
    prepare_request_with_user 'maintenance_coord', 'power'
    post "/request/#{id1}?cmd=changestate&newstate=accepted"
    assert_response :success

    get "/request/#{id1}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    incidentProject=data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    assert_not_equal incidentProject, 'My:Maintenance'

    #validate cleanup
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro3'
    assert_response 404
    get '/source/home:tom:branches:OBS_Maintained:pack2'
    assert_response :success

    # test build and publish flags
    get "/source/#{incidentProject}/_meta"
    assert_xml_tag :parent => { tag: 'build' }, :tag => 'disable'
    assert_xml_tag :parent => { tag: 'publish' }, :tag => 'disable'
    assert_response :success
    get "/source/#{incidentProject}/patchinfo/_meta"
    assert_response :success
    assert_xml_tag :parent => { tag: 'build' }, :tag => 'enable'
    assert_xml_tag :parent => { tag: 'publish' }, :tag => 'enable'
    assert_xml_tag :parent => { tag: 'useforbuild' }, :tag => 'disable'
    # add an old style patch name, only used via %N (in BaseDistro3Channel at the end of this test)
    get "/source/#{incidentProject}/patchinfo/_patchinfo"
    assert_response :success
    pi = ActiveXML::Node.new( @response.body )
    e = pi.add_element 'name'
    e.text = "patch_name"
    e = pi.add_element 'message'
    e.text = "During reboot a popup with a question will appear"
    put "/source/#{incidentProject}/patchinfo/_patchinfo", pi.dump_xml
    assert_response :success

    # create maintenance request with invalid target
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.BaseDistro2.0_LinkedUpdateProject" />
                                     <target project="home:tom" />
                                   </action>
                                 </request>'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'no_maintenance_project' }
    # valid target..
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.BaseDistro2.0_LinkedUpdateProject" />
                                     <target project="'+incidentProject+'" />
                                   </action>
                                 </request>'
    assert_response :success
    assert_xml_tag( :tag => 'target', :attributes => { project: incidentProject } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id2 = node.value(:id)
    # ... but do not use it
    post "/request/#{id2}?cmd=changestate&newstate=revoked"
    assert_response :success

    # create maintenance request for two further packages
    # without specifing target, the default target must get found via attribute
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.BaseDistro2.0_LinkedUpdateProject" />
                                     <options>
                                       <sourceupdate>cleanup</sourceupdate>
                                     </options>
                                   </action>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.linked.BaseDistro2.0_LinkedUpdateProject" />
                                     <options>
                                       <sourceupdate>cleanup</sourceupdate>
                                     </options>
                                   </action>
                                   <state name="new" />
                                   <description>To fix my other bug</description>
                                 </request>'
    assert_response :success
    assert_xml_tag( :tag => 'target', :attributes => { project: 'My:Maintenance' } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id2 = node.value(:id)

    # validate that request is diffable and that the linked package is not double diffed
    post "/request/#{id2}?cmd=diff&view=xml", nil
    assert_response :success
    assert_match(/new_content_0815/, @response.body) # check if our changes are part of the diff
    assert_xml_tag :parent=>{ tag: 'file', attributes: { state: 'added' } }, :tag => 'new', :attributes=>{ name: 'new_file' }
    assert_xml_tag :parent=>{ tag: 'file', attributes: { state: 'added' } }, :tag => 'new', :attributes=>{ name: '_link' } # local link is unexpanded

    # set incident to merge into existing one
    prepare_request_with_user 'maintenance_coord', 'power'
    post "/request/#{id2}?cmd=setincident&incident=#{incidentProject.gsub(/.*:/,'')}"
    assert_response :success

    get "/request/#{id2}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    maintenanceNotNewProject=data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    assert_equal incidentProject, maintenanceNotNewProject

    # try to do it again
    prepare_request_with_user 'maintenance_coord', 'power'
    post "/request/#{id2}?cmd=setincident&incident=#{incidentProject.gsub(/.*:/,'')}"
    assert_response 404
    assert_xml_tag :tag => 'status', :attributes => { code: 'target_not_maintenance' }

    # accept request
    prepare_request_with_user 'maintenance_coord', 'power'
    post "/request/#{id2}?cmd=changestate&newstate=accepted&force=1" # ignore reviews and accept
    assert_response :success

    get "/request/#{id2}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    maintenanceNotNewProject=data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    assert_equal incidentProject, maintenanceNotNewProject

    # no patchinfo was part in source project, got it created ?
    get "/source/#{incidentProject}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag :tag => 'packager', :content => 'tom'
    assert_xml_tag :tag => 'description', :content => 'To fix my bug'

    #validate cleanup
    get '/source/home:tom:branches:OBS_Maintained:pack2'
    assert_response 404

    #
    # Add channels
    #
    # define one
    login_king
    put '/source/BaseDistro3Channel/_meta', '<project name="BaseDistro3Channel" kind="maintenance_release"><title/><description/>
                                         <build><disable/></build>
                                         <publish><enable/></publish>
                                         <person userid="adrian_reader" role="reviewer" />
                                         <repository name="channel_repo">
                                           <arch>i586</arch>
                                         </repository>
                                   </project>'
    assert_response :success
    put '/source/BaseDistro3Channel/_config', "Repotype: rpm-md-legacy\nType: spec"
    assert_response :success
    raw_post '/source/BaseDistro3Channel/_attribute', "<attributes><attribute namespace='OBS' name='MaintenanceIdTemplate'><value>My-BaseDistro3Channel-%Y-%C</value></attribute></attributes>"
    assert_response :success
    put '/source/Channel/_meta', '<project name="Channel"><title/><description/>
                                   </project>'
    assert_response :success
    # create channel package
    put '/source/Channel/BaseDistro3/_meta', '<package project="Channel" name="BaseDistro3"><title/><description/></package>'
    assert_response :success
    post '/source/Channel/BaseDistro3?cmd=importchannel&target_project=BaseDistro3Channel&target_repository=channel_repo', '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <binaries project="BaseDistro3" repository="BaseDistro3_repo" arch="i586">
            <binary name="package" package="pack2.linked" project="BaseDistro2.0" />
          </binaries>
        </channel>'
    assert_response :success
    get '/source/Channel/BaseDistro3/_channel'
    assert_response :success
    # it found the update project
    assert_xml_tag :tag => 'binary', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2.linked' }
    # target repo parameter worked
    assert_xml_tag :tag => 'target', :attributes => { project: 'BaseDistro3Channel', repository: 'channel_repo' }

    put '/source/Channel/BaseDistro3/_channel', '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <target project="BaseDistro3Channel" repository="channel_repo" id_template="UpdateInfoTag-&#37;Y-&#37;C" />
          <binaries project="BaseDistro3" repository="BaseDistro3_repo" arch="i586">
            <binary name="package" package="pack2" supportstatus="l3" />
            <binary name="does_not_exist" />
          </binaries>
        </channel>'
    assert_response :success
    get '/source/Channel/BaseDistro3/_channel'
    assert_response :success
    assert_no_xml_tag :tag => 'binary', :attributes => { project: 'BaseDistro2.0', package: 'pack2.linked' }
    assert_xml_tag :tag => 'binary', :attributes => { project: nil, package: 'pack2', supportstatus: 'l3' }

    # create channel packages and repos
    login_adrian
    post "/source/#{incidentProject}?cmd=addchannels", nil
    assert_response 403
    prepare_request_with_user 'maintenance_coord', 'power'
    post "/source/#{incidentProject}?cmd=addchannels", nil
    assert_response :success
    get "/source/#{incidentProject}/BaseDistro3.Channel/_meta"
    assert_response 404 # not a maintained project
    # make Channel project a maintained project and try again.
    mprj = Project.find_by_name('My:Maintenance')
    MaintainedProject.create(project: Project.find_by_name('Channel'), maintenance_project: mprj)

    post "/source/#{incidentProject}?cmd=addchannels", nil
    assert_response :success
    get "/source/#{incidentProject}/BaseDistro3.Channel/_meta"
    assert_response :success
    assert_xml_tag :tag => 'enable', :attributes => { repository: 'BaseDistro3Channel' },
                   :parent => { tag: 'build' }
    get "/source/#{incidentProject}/_meta"
    assert_response :success
    assert_xml_tag :tag => 'path', :attributes => { project: 'BaseDistro3Channel', repository: 'channel_repo' },
                   :parent => { tag: 'repository', attributes: { name: 'BaseDistro3Channel' } }
    assert_xml_tag :tag => 'releasetarget', :attributes => { project: 'BaseDistro3Channel', repository: 'channel_repo', trigger: 'maintenance' },
                   :parent => { tag: 'repository', attributes: { name: 'BaseDistro3Channel' } }

    # inject build results
    run_scheduler('x86_64')
    run_scheduler('i586')
    inject_build_job( incidentProject, 'pack2.BaseDistro3', 'BaseDistro3', 'i586')
    run_scheduler('x86_64')
    run_scheduler('i586')
    wait_for_publisher
    get "/build/#{incidentProject}/_result"
    assert_response :success
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro3', arch: 'i586', state: 'published' } }, :tag => 'status', :attributes => { package: 'patchinfo', code: 'succeeded' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro3Channel', arch: 'i586', state: 'published' } }, :tag => 'status', :attributes => { package: 'patchinfo', code: 'succeeded' }

    # check published search db
    get "/search/published/binary/id?match=project='"+incidentProject+"'"
    assert_response :success
    assert_xml_tag :tag => "binary", :attributes => { name: "package", project: incidentProject, package: "patchinfo",
                                                      repository: "BaseDistro3", version: "1.0", release: "1", arch: "i586",
                                                      filename: "package-1.0-1.i586.rpm",
                                                      filepath: "My:/Maintenance:/0/BaseDistro3/i586/package-1.0-1.i586.rpm",
                                                      baseproject: "BaseDistro3", type: "rpm" }
    assert_xml_tag :tag => "binary", :attributes => { name: "package", project: incidentProject, package: "patchinfo",
                                                      repository: "BaseDistro3Channel", version: "1.0", release: "1", arch: "i586",
                                                      filename: "package-1.0-1.i586.rpm",
                                                      filepath: "My:/Maintenance:/0/BaseDistro3Channel/i586/package-1.0-1.i586.rpm",
                                                      baseproject: "BaseDistro3Channel", type: "rpm" }


    # create release request
    post '/request?cmd=create&ignore_build_state=1', '<request>
                                   <action type="maintenance_release">
                                     <source project="'+incidentProject+'" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag :tag => "review", :attributes => { by_user: "adrian_reader", state: "new" }     # from channel
    assert_xml_tag :tag => "review", :attributes => { by_user: "fred", state: "new" }
    assert_xml_tag :tag => "review", :attributes => { by_group: "test_group", state: "new" }
    # no submit action
    assert_no_xml_tag :tag => 'action', :attributes => { type: 'submit' }
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)
    # revoke try new request
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # and check what happens after modifing _channel file
    put '/source/My:Maintenance:0/BaseDistro3.Channel/_channel', '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <target project="BaseDistro3Channel" repository="channel_repo" id_template="UpdateInfoTagNew-&#37;N-&#37;Y-&#37;C" />
          <binaries project="BaseDistro3" repository="BaseDistro3_repo" arch="i586">
            <binary name="package" package="pack2" project="BaseDistro3" />
          </binaries>
        </channel>'
    assert_response :success

    post '/request?cmd=create&ignore_build_state=1', '<request>
                                   <action type="maintenance_release">
                                     <source project="'+incidentProject+'" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)
    # submit action
    assert_xml_tag :tag => 'target', :attributes => { project: 'Channel', package: 'BaseDistro3' },
                   :parent => { tag: 'action', attributes: { type: 'submit' } }
    # channel package is not released
    assert_no_xml_tag :tag => 'source', :attributes => { project: 'My:Maintenance:0', package: 'BaseDistro3.Channel' },
                   :parent => { tag: 'action', attributes: { type: 'maintenance_release' } }
    # but it has a source change, so submit action
    assert_xml_tag :tag => 'source', :attributes => { project: 'My:Maintenance:0', package: 'BaseDistro3.Channel' },
                   :parent => { tag: 'action', attributes: { type: 'submit' } }
    # no release patchinfo into channel
    assert_no_xml_tag :tag => 'target', :attributes => { project: 'Channel', package: 'patchinfo.0' },
                   :parent => { tag: 'action', attributes: { type: 'maintenance_release' } }
    # release of patchinfos
    assert_xml_tag :tag => 'target', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'patchinfo.0' },
                   :parent => { tag: 'action', attributes: { type: 'maintenance_release' } }
    assert_xml_tag :tag => 'target', :attributes => { project: 'BaseDistro3', package: 'patchinfo.0' },
                   :parent => { tag: 'action', attributes: { type: 'maintenance_release' } }
    assert_xml_tag :tag => 'target', :attributes => { project: 'BaseDistro3Channel', package: 'patchinfo.0' },
                   :parent => { tag: 'action', attributes: { type: 'maintenance_release' } }

    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)

    # accept new request
    login_king
    post "/request/#{reqid}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get "/request/#{reqid}"
    assert_response :success
    # check for acceptinfo
#   assert_xml_tag :parent => { :tag => 'action', :attributes => { :type=> 'maintenance_release'} },
#                  :tag => 'source', :attributes => { :project=> 'My:Maintenance:0', :package=> 'pack2.BaseDistro3'},
#                  :tag => 'target', :attributes => { :project=> 'BaseDistro3', :package=> 'pack2.0'},
#                  :tag => 'acceptinfo', :attributes => { :rev=> '1', :srcmd5=> 'd4009ce72631596f0b7f691e615cfe2c', :osrcmd5 => "d41d8cd98f00b204e9800998ecf8427e" }

    # diffing works
    post "/request/#{reqid}?cmd=diff&view=xml", nil
    assert_response :success
#    assert_xml_tag :tag => 'old', :attributes => { :project=> 'BaseDistro2.0:LinkedUpdateProject', :package=> 'pack2.0'},
#                   :tag => 'new', :attributes => { :project=> 'BaseDistro2.0:LinkedUpdateProject', :package=> 'pack2.0'}
    run_scheduler('x86_64')
    run_scheduler('i586')
    wait_for_publisher

    # collect the job results
    get "/build/#{incidentProject}/_result"
    assert_response :success
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro3', arch: 'i586', state: 'published' } }, :tag => 'status', :attributes => { package: 'patchinfo', code: 'locked' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro3Channel', arch: 'i586', state: 'published' } }, :tag => 'status', :attributes => { package: 'patchinfo', code: 'locked' }

    # validate update info channel tag
    incidentID=incidentProject.gsub(/.*:/,'')
    get "/build/BaseDistro3Channel/channel_repo/i586/patchinfo.#{incidentID}/updateinfo.xml"
    assert_response :success
    # check for changed updateinfoid.
    assert_xml_tag :parent => { tag: 'update', attributes: { from: 'tom', status: 'stable', type: 'recommended', version: '1' } }, :tag => 'id', :content => "UpdateInfoTagNew-patch_name-#{Time.now.utc.year.to_s}-1"

    # repo is configured as legacy rpm-md, so we require short meta data file names
    get '/build/BaseDistro3Channel/_result'
    assert_response :success
    assert_xml_tag :tag => 'result', :attributes => {
        project: 'BaseDistro3Channel',
        repository: 'channel_repo',
        arch: 'i586',
        code: 'published',
        state: 'published' }
    get '/published/BaseDistro3Channel/channel_repo/repodata'
    assert_response :success
    assert_xml_tag :tag => 'entry', :attributes => { name: 'filelists.xml.gz' }  # by createrepo
    assert_xml_tag :tag => 'entry', :attributes => { name: 'other.xml.gz' }
    assert_xml_tag :tag => 'entry', :attributes => { name: 'primary.xml.gz' }
    assert_xml_tag :tag => 'entry', :attributes => { name: 'repomd.xml' }
    assert_xml_tag :tag => 'entry', :attributes => { name: 'updateinfo.xml.gz' } # by modifyrepo

    # event handling
    get '/search/released/binary/id', match: "repository/[@project = 'BaseDistro3' and @name = 'BaseDistro3_repo']"
    assert_response :success
#    assert_no_xml_tag :tag => 'binary', :attributes => { name: 'package_newweaktags' }
    UpdateNotificationEvents.new.perform
    get '/search/released/binary', match: "repository/[@project = 'BaseDistro3' and @name = 'BaseDistro3_repo']"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'binary', :attributes =>
                     { name: 'package_newweaktags', version: "1.0", release: "1", arch: "x86_64" } },
                   :tag => 'publish', :attributes => { package: "pack2" }
    assert_no_xml_tag :parent => { :tag => 'binary', :attributes =>
                     { name: 'package_newweaktags', version: "1.0", release: "1", arch: "i586" } },
                   :tag => 'obsolete'
    assert_xml_tag :parent => { :tag => 'binary', :attributes =>
                     { name: 'package', version: "1.0", release: "1", arch: "i586" } },
                   :tag => 'build', :attributes => { time: "2014-07-03 12:26:54 UTC" }
    assert_xml_tag :parent => { :tag => 'binary', :attributes =>
                     { name: 'package', version: "1.0", release: "1", arch: "i586" } },
                   :tag => 'disturl', :content => "obs://testsuite/BaseDistro/repo/ce167c27b536e6ca39f8d951fa02a4ff-package"
    assert_xml_tag :tag => 'updatefor', :attributes => { project: "BaseDistro", product: "fixed" }

    assert_xml_tag :parent => { :tag => 'binary', :attributes =>
           { name: 'package', project: "BaseDistro3", repository: "BaseDistro3_repo", arch: "i586" } },
                   :tag => 'operation', :content => "modified"
    assert_xml_tag :parent => { :tag => 'binary', :attributes =>
           { name: 'package', project: "BaseDistro3", repository: "BaseDistro3_repo", arch: "src" } },
                   :tag => 'operation', :content => "added"
    assert_xml_tag :parent => { :tag => 'binary', :attributes =>
           { name: 'dropped', project: "BaseDistro3", repository: "BaseDistro3_repo", arch: "i586" } },
                   :tag => 'operation', :content => "added"

    # search via official updateinfo id tag
    get '/search/released/binary', match: "updateinfo/@id = 'UpdateInfoTagNew-patch_name-#{Time.now.utc.year.to_s}-1'"
    assert_response :success
    assert_xml_tag :tag => 'binary', :attributes =>
           { name: 'package', project: "BaseDistro3Channel", repository: "channel_repo", arch: "i586" }
    assert_xml_tag :tag => 'binary', :attributes =>
           { name: 'package', project: "BaseDistro3Channel", repository: "channel_repo", arch: "src" }
    assert_xml_tag :tag => 'updateinfo', :attributes =>
           { id: "UpdateInfoTagNew-patch_name-#{Time.now.utc.year.to_s}-1", version: "1" }

    # test retracting of released updates
    # cleans up the backend and validates that DB constraints get a cleanup
    delete '/source/BaseDistro3Channel/patchinfo.0'
    assert_response :success
    delete '/source/BaseDistro3/patchinfo.0'
    assert_response :success
    delete '/source/BaseDistro3/pack2.0'
    assert_response :success

    #cleanup
    login_king
    delete '/source/BaseDistro3Channel'
    assert_response 400 # incident still refers to it
    delete "/source/#{incidentProject}"
    assert_response 403 # still locked, so unlock it ...
    post "/source/#{incidentProject}", { cmd: 'unlock', comment: 'cleanup' }
    assert_response :success
    delete "/source/#{incidentProject}"
    assert_response :success
    delete '/source/Channel'
    assert_response :success
  end

  def test_OBS_BranchTarget
    login_king
    put '/source/ServicePack/_meta', "<project name='ServicePack'><title/><description/><link project='kde4'/></project>"
    assert_response :success
    post '/source/ServicePack/_attribute', "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post '/source/ServicePack/_attribute', "<attributes><attribute namespace='OBS' name='BranchTarget' /></attributes>"
    assert_response :success

    login_tom
    post '/source', :cmd => 'branch', :package => 'kdelibs'
    assert_response :success
    assert_xml_tag :tag => 'data', :attributes => { name: 'targetproject' }, :content => 'home:tom:branches:OBS_Maintained:kdelibs'
    assert_xml_tag :tag => 'data', :attributes => { name: 'targetpackage' }, :content => 'kdelibs.kde4'
    assert_xml_tag :tag => 'data', :attributes => { name: 'sourceproject' }, :content => 'ServicePack'
    assert_xml_tag :tag => 'data', :attributes => { name: 'sourcepackage' }, :content => 'kdelibs'

    #cleanup
    delete '/source/home:tom:branches:OBS_Maintained:kdelibs'
    assert_response :success
  end

  def test_mbranch_and_maintenance_entire_project_request
    login_king
    put '/source/ServicePack/_meta', "<project name='ServicePack'><title/><description/><link project='kde4'/></project>"
    assert_response :success

    # setup maintained attributes
    prepare_request_with_user 'maintenance_coord', 'power'
    # an entire project
    post '/source/BaseDistro/_attribute', "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    # single packages
    post '/source/BaseDistro2.0/pack2/_attribute', "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post '/source/BaseDistro3/pack2/_attribute', "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post '/source/ServicePack/_attribute', "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success

    # search for maintained packages like osc is doing
    get '/search/package?match=%28%40name+%3D+%27pack2%27%29+and+%28project%2Fattribute%2F%40name%3D%27OBS%3AMaintained%27+or+attribute%2F%40name%3D%27OBS%3AMaintained%27%29'
    assert_response :success
    assert_xml_tag :tag => 'collection', :children => { count: 3 }
   
    # do the real mbranch for default maintained packages
    login_tom
    post '/source', :cmd => 'branch', :package => 'pack2', :noaccess => 1
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/_meta'
    assert_response :success
    assert_xml_tag( :parent => { tag: 'access' }, :tag => 'disable', :content => nil )
    delete '/source/home:tom:branches:OBS_Maintained:pack2'
    assert_response :success
    post '/source', :cmd => 'branch', :package => 'pack2'
    assert_response :success

    # validate result
    get '/source/home:tom:branches:OBS_Maintained:pack2'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/_meta'
    assert_response :success
    assert_no_xml_tag( :parent => { tag: 'access' }, :tag => 'disable', :content => nil )
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject/_meta'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update/_meta'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject/_link'
    assert_response :success
    assert_xml_tag :tag => 'link', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' }
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update/_link'
    assert_response :success
    assert_xml_tag :tag => 'link', :attributes => { project: 'BaseDistro:Update', package: 'pack2' }
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update/_history'
    assert_response :success
    assert_xml_tag :tag => 'comment', :content => %r{fetch updates from devel package}
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro3/_link'
    assert_response :success
    assert_xml_tag :tag => 'link', :attributes => { project: 'BaseDistro3', package: 'pack2' }
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.linked.BaseDistro2.0_LinkedUpdateProject/_link'
    assert_response :success
    assert_no_xml_tag :tag => 'link', :attributes => { project: 'BaseDistro2.0' }
    assert_xml_tag :tag => 'link', :attributes => { package: 'pack2.BaseDistro2.0_LinkedUpdateProject' }

    # test branching another package set into same project
    post '/source', :cmd => 'branch', :package => 'pack1', :target_project => 'home:tom:branches:OBS_Maintained:pack2'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack1.BaseDistro_Update'
    assert_response :success

    # add a new package with defined link target
    post '/source/BaseDistro:Update/packN', :cmd => 'branch', :target_project => 'home:tom:branches:OBS_Maintained:pack2', :missingok => 1, :extend_package_names => 1
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/packN.BaseDistro_Update'
    assert_response :success

    # test branching another package set into same project from same project
    post '/source', :cmd => 'branch', :package => 'pack3', :target_project => 'home:tom:branches:OBS_Maintained:pack2'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack3.BaseDistro_Update'
    assert_response :success
    # test branching another package only reachable via project link into same project
    post '/source', :cmd => 'branch', :package => 'kdelibs', :target_project => 'home:tom:branches:OBS_Maintained:pack2', :noaccess => 1
    assert_response 403
    assert_xml_tag :tag => 'status', :attributes => { code: 'create_project_no_permission' }

#FIXME: backend has a bug that it destroys the link even with keeplink if opackage has no rev
    put '/source/home:coolo:test/kdelibs_DEVEL_package/DUMMY', 'CONTENT'
    assert_response :success

    # add an issue 
    put '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update/dummy.changes', 'DUMMY bnc#1042'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update?view=issues'
    assert_response :success
    assert_no_xml_tag :parent => { tag: 'issue' }, :tag => 'issue', :attributes => { change: nil }
    assert_no_xml_tag :parent => { tag: 'issue' }, :tag => 'issue', :attributes => { change: '' }
    assert_xml_tag :parent => { tag: 'issue', attributes: { change: 'added' } }, :tag => 'name', :content => '1042'

    post '/source', :cmd => 'branch', :package => 'kdelibs', :target_project => 'home:tom:branches:OBS_Maintained:pack2'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/kdelibs.kde4/_link'
    assert_response :success
    # Indirect packages need to link and build in update project of former ServicePack, because current ServicePack
    # may introduce more incompatibilities due to changed packages used for building
    assert_xml_tag :tag => 'link', :attributes => { project: 'kde4', package: 'kdelibs' }

    # do some file changes
    put '/source/home:tom:branches:OBS_Maintained:pack2/kdelibs.kde4/new_file', 'new_content_0815'
    assert_response :success
    put '/source/home:tom:branches:OBS_Maintained:pack2/pack3.BaseDistro_Update/new_file', 'new_content_2137'
    assert_response :success

    # validate created project meta
    get '/source/home:tom:branches:OBS_Maintained:pack2/_meta'
    assert_response :success
    assert_xml_tag :parent => { tag: 'build' }, :tag => 'disable'

    assert_xml_tag :parent => { tag: 'repository', attributes: { name: 'BaseDistro2.0_LinkedUpdateProject' } },
               :tag => 'path', :attributes => { repository: 'BaseDistro2LinkedUpdateProject_repo', project: 'BaseDistro2.0:LinkedUpdateProject' }
    assert_xml_tag :parent => { tag: 'repository', attributes: { name: 'BaseDistro2.0_LinkedUpdateProject' } },
               :tag => 'arch', :content => 'i586'

    assert_xml_tag :parent => { tag: 'repository', attributes: { name: 'BaseDistro_Update' } },
               :tag => 'path', :attributes => { repository: 'BaseDistroUpdateProject_repo', project: 'BaseDistro:Update' }

    assert_xml_tag( :tag => 'releasetarget', :attributes => { project: 'BaseDistro:Update', repository: 'BaseDistroUpdateProject_repo', trigger: nil } )

    assert_xml_tag( :tag => 'releasetarget', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', repository: 'BaseDistro2LinkedUpdateProject_repo', trigger: nil } )

    # validate created package meta
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject/_meta'
    assert_response :success
    assert_xml_tag :tag => 'package', :attributes => { name: 'pack2.BaseDistro2.0_LinkedUpdateProject', project: 'home:tom:branches:OBS_Maintained:pack2' }
    assert_xml_tag :parent => { tag: 'build' }, :tag => 'enable', :attributes => { repository: 'BaseDistro2.0_LinkedUpdateProject' }

    # and branch same package again and expect error
    post '/source', :cmd => 'branch', :package => 'pack1', :target_project => 'home:tom:branches:OBS_Maintained:pack2'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'double_branch_package' }
    assert_match(/branch target package already exists:/, @response.body)

    # create patchinfo
    post '/source/BaseDistro?cmd=createpatchinfo'
    assert_response 403
    post '/source/home:tom:branches:OBS_Maintained:pack2?cmd=createpatchinfo'
    assert_response :success
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetpackage' }, :content => 'patchinfo')
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetproject' }, :content => 'home:tom:branches:OBS_Maintained:pack2')
    get '/source/home:tom:branches:OBS_Maintained:pack2/patchinfo/_meta'
    assert_response :success
    assert_xml_tag :parent => { tag: 'build' }, :tag => 'enable'
    assert_xml_tag :parent => { tag: 'publish' }, :tag => 'enable'
    assert_xml_tag :parent => { tag: 'useforbuild' }, :tag => 'disable'

    # delete kdelibs package again or incident creation will fail since it does not point to a maintained project.
    delete '/source/home:tom:branches:OBS_Maintained:pack2/kdelibs.kde4'
    assert_response :success

    # create maintenance request
    # without specifing target, the default target must get found via attribute
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" />
                                     <options>
                                       <sourceupdate>cleanup</sourceupdate>
                                     </options>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag( :tag => 'target', :attributes => { project: 'My:Maintenance' } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value(:id)
    assert_xml_tag( :tag => 'request', :children => { count: 8, only: { tag: 'action' } })
    assert_xml_tag( :tag => 'source', :attributes => { project: 'home:tom:branches:OBS_Maintained:pack2' } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'My:Maintenance' } )
    assert_xml_tag( :tag => 'target', :attributes => { releaseproject: 'BaseDistro3' } )
    assert_xml_tag( :tag => 'target', :attributes => { releaseproject: 'BaseDistro2.0:LinkedUpdateProject' } )
    assert_xml_tag( :tag => 'target', :attributes => { releaseproject: 'BaseDistro:Update' } )

    # validate that request is diffable (not broken)
    post "/request/#{id}?cmd=diff&view=xml", nil
    assert_response :success
    assert_match(/new_content_2137/, @response.body) # check if our changes are part of the diff

    # store data for later checks
    get '/source/home:tom:branches:OBS_Maintained:pack2/_meta'
    oprojectmeta = ActiveXML::Node.new(@response.body)
    assert_response :success

    # accept request
    prepare_request_with_user 'maintenance_coord', 'power'
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    incidentProject=data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    assert_not_equal incidentProject, 'My:Maintenance'

    #validate cleanup
    get '/source/home:tom:branches:OBS_Maintained:pack2'
    assert_response 404

    # validate created project
    get "/source/#{incidentProject}/_meta"
    assert_response :success
    assert_xml_tag( :parent => { tag: 'build' }, :tag => 'disable', :content => nil )
    node = ActiveXML::Node.new(@response.body)
    # repository definition must be the same, except for the maintenance trigger
    node.each('repository') do |r|
      rt = r.find_first('releasetarget')
      assert_not_nil rt
      assert_equal 'maintenance', rt.value('trigger')
      rt.delete_attribute('trigger')
    end
    assert_equal node.find_first('repository').dump_xml, oprojectmeta.find_first('repository').dump_xml
    assert_equal node.find_first('build').dump_xml, oprojectmeta.find_first('build').dump_xml

    get "/source/#{incidentProject}"
    assert_response :success
    assert_xml_tag( :tag => 'directory', :attributes => { count: '8' } )

    get "/source/#{incidentProject}/pack2.BaseDistro2.0_LinkedUpdateProject/_meta"
    assert_response :success
    assert_xml_tag( :tag => 'enable', :parent => { tag: 'build' }, :attributes => { repository: 'BaseDistro2.0_LinkedUpdateProject' } )

    get "/source/#{incidentProject}/pack2.BaseDistro_Update?view=issues"
    assert_response :success
    assert_no_xml_tag :parent => { tag: 'issue' }, :tag => 'issue', :attributes => { change: nil }
    assert_no_xml_tag :parent => { tag: 'issue' }, :tag => 'issue', :attributes => { change: '' }
    assert_xml_tag :parent => { tag: 'issue', attributes: { change: 'added' } }, :tag => 'name', :content => '1042'

    get "/source/#{incidentProject}/patchinfo/_meta"
    assert_response :success
    assert_xml_tag( :tag => 'enable', :parent => { tag: 'build' } )
    assert_xml_tag( :tag => 'enable', :parent => { tag: 'publish' } )

    get "/source/#{incidentProject}/patchinfo?view=issues"
    assert_response :success
    assert_no_xml_tag :parent => { tag: 'issue' }, :tag => 'issue', :attributes => { change: nil }
    assert_no_xml_tag :parent => { tag: 'issue' }, :tag => 'issue', :attributes => { change: '' }
    assert_xml_tag :parent => { tag: 'issue', attributes: { change: 'kept' } }, :tag => 'name', :content => '1042'
  end

  def test_create_maintenance_incident
    login_king
    put '/source/Temp:Maintenance/_meta', '<project name="Temp:Maintenance" kind="maintenance">
                                             <title/> <description/>
                                             <person userid="maintenance_coord" role="maintainer"/>
                                           </project>'
    assert_response :success

    reset_auth 
    post '/source/Temp:Maintenance', :cmd => 'createmaintenanceincident'
    assert_response 401

    login_adrian
    post '/source/Temp:Maintenance', :cmd => 'createmaintenanceincident'
    assert_response 403
    post '/source/home:adrian', :cmd => 'createmaintenanceincident'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'incident_has_no_maintenance_project' }

    prepare_request_with_user 'maintenance_coord', 'power'
    # create a public maintenance incident
    post '/source/Temp:Maintenance', :cmd => 'createmaintenanceincident'
    assert_response :success
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetproject' } )
    data = REXML::Document.new(@response.body)
    incidentProject=data.elements['/status/data'].text
    #incidentID=incidentProject.gsub( /^Temp:Maintenance:/, "" )
    get "/source/#{incidentProject}/_meta"
    assert_xml_tag( :tag => 'project', :attributes => { kind: 'maintenance_incident' } )
    assert_xml_tag( :parent => { tag: 'build' }, :tag => 'disable', :content => nil )
    assert_no_xml_tag( :parent => { tag: 'access' }, :tag => 'disable', :content => nil )
    assert_xml_tag( :attributes => { role: 'maintainer', userid: 'maintenance_coord' }, :tag => 'person', :content => nil )
    assert_xml_tag( :attributes => { role: 'bugowner', userid: 'maintenance_coord' }, :tag => 'person', :content => nil )

    # create a maintenance incident under embargo
    post '/source/Temp:Maintenance?cmd=createmaintenanceincident&noaccess=1', nil
    assert_response :success
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetproject' } )
    data = REXML::Document.new(@response.body)
    incidentProject2=data.elements['/status/data'].text
    #incidentID2=incidentProject2.gsub( /^Temp:Maintenance:/, "" )
    get "/source/#{incidentProject2}/_meta"
    assert_xml_tag( :parent => { tag: 'build' }, :tag => 'disable', :content => nil )
    assert_xml_tag( :parent => { tag: 'access' }, :tag => 'disable', :content => nil )
    assert_xml_tag( :attributes => { role: 'maintainer', userid: 'maintenance_coord' }, :tag => 'person', :content => nil )

    # cleanup
    delete '/source/Temp:Maintenance'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'delete_error' }
    assert_match(/This maintenance project has incident projects/, @response.body)
    delete "/source/#{incidentProject}"
    assert_response :success
    delete "/source/#{incidentProject2}"
    assert_response :success
    delete '/source/Temp:Maintenance'
    assert_response :success
  end

  def test_manual_branch_with_extend_names
    # submit packages via mbranch
    login_tom
    post '/source/BaseDistro2.0/pack2', :cmd => 'branch', :target_package => 'DUMMY_package', :extend_package_names => '1'
    assert_response :success
    assert_xml_tag( :tag => 'data', :attributes => { name: 'sourceproject' }, :content => 'BaseDistro2.0:LinkedUpdateProject')
    assert_xml_tag( :tag => 'data', :attributes => { name: 'sourcepackage' }, :content => 'pack2')
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetproject' }, :content => 'home:tom:branches:BaseDistro2.0:LinkedUpdateProject')
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetpackage' }, :content => 'DUMMY_package.BaseDistro2.0_LinkedUpdateProject')
    get '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
    assert_xml_tag( :tag => 'entry', :attributes => { name: 'DUMMY_package.BaseDistro2.0_LinkedUpdateProject' })
    assert_xml_tag( :tag => 'entry', :attributes => { name: 'pack2.linked.BaseDistro2.0_LinkedUpdateProject' })

    # check link of branched package
    get '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/DUMMY_package.BaseDistro2.0_LinkedUpdateProject/_link'
    assert_response :success
    assert_xml_tag( :tag => 'link', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' })

    # check link of local linked package
    get '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2.linked.BaseDistro2.0_LinkedUpdateProject/_link'
    assert_response :success
    assert_xml_tag( :tag => 'link', :attributes => { project: nil })
    assert_xml_tag( :tag => 'link', :attributes => { package: 'DUMMY_package.BaseDistro2.0_LinkedUpdateProject' })

    #cleanup
    delete '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
  end

  def test_create_maintenance_project_and_release_packages

    # the birthday of J.K.
    Timecop.freeze(2010, 7, 12)

    # setup 'My:Maintenance' as a maintenance project by fetching it's meta and set a type
    login_king
    get '/source/My:Maintenance/_meta'
    assert_response :success
    maintenance_project_meta = REXML::Document.new(@response.body)
    maintenance_project_meta.elements['/project'].attributes['kind'] = 'maintenance'
    raw_put '/source/My:Maintenance/_meta', maintenance_project_meta.to_s
    assert_response :success

    prepare_request_with_user 'maintenance_coord', 'power'
    raw_post '/source/My:Maintenance/_attribute', "<attributes><attribute namespace='OBS' name='MaintenanceIdTemplate'><value>My-%N-%Y-%C</value></attribute></attributes>"
    assert_response :success

    Timecop.freeze(1)
    # setup a maintained distro
    post '/source/BaseDistro2.0/_attribute', "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    Timecop.freeze(1)
    post '/source/BaseDistro2.0/_attribute', "<attributes><attribute namespace='OBS' name='UpdateProject' > <value>BaseDistro2.0:LinkedUpdateProject</value> </attribute> </attributes>"
    assert_response :success
    Timecop.freeze(1)
    post '/source/BaseDistro3/_attribute', "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success

    # validate correct :Update project setup
    get '/source/BaseDistro2.0:LinkedUpdateProject/_meta'
    assert_response :success
    assert_xml_tag( :parent => { tag: 'build' }, :tag => 'disable', :attributes => { repository: nil, arch: nil } )
    assert_xml_tag( :parent => { tag: 'publish' }, :tag => 'disable', :attributes => { repository: nil, arch: nil } )

    # create a maintenance incident
    Timecop.freeze(1)
    post '/source', :cmd => 'createmaintenanceincident', :noaccess => 1
    assert_response :success
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetproject' } )
    data = REXML::Document.new(@response.body)
    incidentProject=data.elements['/status/data'].text
    incidentID=incidentProject.gsub( /^My:Maintenance:/, '')
    get "/source/#{incidentProject}/_meta"
    assert_response :success
    assert_xml_tag( :parent => { tag: 'access' }, :tag => 'disable', :content => nil )
    assert_xml_tag( :parent => { tag: 'build' }, :tag => 'disable', :content => nil )
    assert_xml_tag( :parent => { tag: 'publish' }, :tag => 'disable', :content => nil )
    assert_xml_tag( :tag => 'project', :attributes => { name: incidentProject, kind: 'maintenance_incident' } )

    # submit packages via mbranch
    Timecop.freeze(1)
    post '/source', :cmd => 'branch', :package => 'pack2', :target_project => incidentProject
    assert_response :success

    # correct branched ?
    get '/source/'+incidentProject+'/pack2.BaseDistro2.0_LinkedUpdateProject/_link'
    assert_response :success
    assert_xml_tag( :tag => 'link', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' } )
    get '/source/'+incidentProject
    assert_response :success
    assert_xml_tag( :tag => 'directory', :attributes => { count: '3' } )
    assert_xml_tag( :tag => 'entry', :attributes => { name: 'pack2.BaseDistro2.0_LinkedUpdateProject' } )
    assert_xml_tag( :tag => 'entry', :attributes => { name: 'pack2.linked.BaseDistro2.0_LinkedUpdateProject' } )
    assert_xml_tag( :tag => 'entry', :attributes => { name: 'pack2.BaseDistro3' } )
    get '/source/'+incidentProject+'/_meta'
    assert_response :success
    assert_xml_tag( :tag => 'path', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', repository: 'BaseDistro2LinkedUpdateProject_repo' } )
    assert_xml_tag( :tag => 'releasetarget', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', repository: 'BaseDistro2LinkedUpdateProject_repo', trigger: 'maintenance' } )
    assert_xml_tag( :tag => 'releasetarget', :attributes => { project: 'BaseDistro3', repository: 'BaseDistro3_repo', trigger: 'maintenance' } )
    # correct vrev ?
    get '/source/'+incidentProject+'/pack2.BaseDistro2.0_LinkedUpdateProject?expand=1'
    assert_response :success
    assert_xml_tag( :tag => 'directory', :attributes => { vrev: '2.7' } )
    # validate package meta
    get '/source/'+incidentProject+'/pack2.BaseDistro2.0_LinkedUpdateProject/_meta'
    assert_response :success
    assert_xml_tag( :parent => { tag: 'build' }, :tag => 'enable', :attributes => { repository: 'BaseDistro2.0_LinkedUpdateProject' } )
    get '/source/'+incidentProject+'/pack2.linked.BaseDistro2.0_LinkedUpdateProject/_meta'
    assert_response :success
    assert_xml_tag( :parent => { tag: 'build' }, :tag => 'enable', :attributes => { repository: 'BaseDistro2.0_LinkedUpdateProject' } )
    get '/source/'+incidentProject+'/pack2.BaseDistro3/_meta'
    assert_response :success
    assert_xml_tag( :parent => { tag: 'build' }, :tag => 'enable', :attributes => { repository: 'BaseDistro3' } )
    # set lock disabled to check later the valid result when enabling
    post "/source/#{incidentProject}?cmd=set_flag&flag=lock&status=disable"
    assert_response :success

    # create some changes, including issue tracker references
    Timecop.freeze(1)
    raw_put '/source/'+incidentProject+'/pack2.BaseDistro2.0_LinkedUpdateProject/dummy.changes', 'DUMMY bnc#1042'
    assert_response :success
    Timecop.freeze(1)
    post '/source/'+incidentProject+'/pack2.BaseDistro2.0_LinkedUpdateProject?unified=1&cmd=diff&filelimit=0&expand=1'
    assert_response :success
    assert_match(/DUMMY bnc#1042/, @response.body)

    # add a new package with defined link target
    Timecop.freeze(1)
    post '/source/BaseDistro2.0/packNew', :cmd => 'branch', :target_project => incidentProject, :missingok => 1, :extend_package_names => 1, :add_repositories => 1
    assert_response :success
    Timecop.freeze(1)
    raw_put "/source/#{incidentProject}/packNew.BaseDistro2.0_LinkedUpdateProject/packageNew.spec", File.open("#{Rails.root}/test/fixtures/backend/binary/packageNew.spec").read
    assert_response :success

    # search will find this new and not yet processed incident now.
    get '/search/project', :match => '[repository/releasetarget/@trigger="maintenance"]'
    assert_response :success
    assert_xml_tag :parent => { tag: 'collection' },  :tag => 'project', :attributes => { name: incidentProject }

    # Create patchinfo informations
    Timecop.freeze(1)
    post "/source/#{incidentProject}?cmd=createpatchinfo&force=1"
    assert_response :success
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetpackage' }, :content => 'patchinfo')
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetproject' }, :content => incidentProject )
    # add reader role for adrian
    get '/source/' + incidentProject + '/_meta'
    assert_response :success
    meta = ActiveXML::Node.new( @response.body )
    meta.add_element 'person', { userid: 'adrian', role: 'reader' }
    Timecop.freeze(1)
    put '/source/' + incidentProject + '/_meta', meta.dump_xml
    assert_response :success
    get "/source/#{incidentProject}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag( :tag => 'patchinfo', :attributes => { incident: incidentID } )
    #FIXME: add another patchinfo pointing to a third place
    # add required informations about the update
    pi = ActiveXML::Node.new( @response.body )
    pi.find_first('summary').text = 'if you are bored'
    pi.find_first('description').text = 'if you are bored and really want fixes'
    pi.find_first('rating').text = 'important'
    pi.add_element('name').text = 'oldname'
    pi.add_element 'issue', { 'id' => '0815', 'tracker' => 'bnc'}
    pi.add_element 'releasetarget', { project: 'BaseDistro2.0:LinkedUpdateProject' }
    pi.add_element 'releasetarget', { project: 'BaseDistro3' }
    Timecop.freeze(1)
    raw_put "/source/#{incidentProject}/patchinfo/_patchinfo", pi.dump_xml
    assert_response :success
    # add broken releasetarget
    pi.add_element 'releasetarget', { project: 'home:tom' } # invalid target
    Timecop.freeze(1)
    raw_put "/source/#{incidentProject}/patchinfo/_patchinfo", pi.dump_xml
    assert_response 404
    assert_xml_tag :tag => 'status', :attributes => { code: 'releasetarget_not_found' }
    # add broken tracker
    pi.add_element 'issue', { 'id' => '0815', 'tracker' => 'INVALID'} # invalid tracker
    raw_put "/source/#{incidentProject}/patchinfo/_patchinfo", pi.dump_xml
    assert_response 404
    assert_xml_tag :tag => 'status', :attributes => { code: 'tracker_not_found' }
    # continue
    get "/source/#{incidentProject}/patchinfo/_meta"
    assert_xml_tag( :parent => { tag: 'build' }, :tag => 'enable', :attributes => { repository: nil, arch: nil } )
    assert_no_xml_tag( :parent => { tag: 'publish' }, :tag => 'enable', :attributes => { repository: nil, arch: nil } ) # not published due to access disable
    get "/source/#{incidentProject}/patchinfo?view=issues"
    assert_response :success
    assert_no_xml_tag :parent => { tag: 'issue' }, :tag => 'issue', :attributes => { change: nil }
    assert_no_xml_tag :parent => { tag: 'issue' }, :tag => 'issue', :attributes => { change: '' }
    assert_xml_tag :parent => { tag: 'issue' }, :tag => 'name', :content => '1042'
    assert_xml_tag :parent => { tag: 'issue' }, :tag => 'name', :content => '0815'
    assert_xml_tag :parent => { tag: 'issue' }, :tag => 'tracker', :content => 'bnc'

    # add another issue and update patchinfo
    Timecop.freeze(1)
    raw_put '/source/'+incidentProject+'/pack2.BaseDistro2.0_LinkedUpdateProject/dummy.changes', 'DUMMY bnc#1042 CVE-2009-0815 bnc#4201'
    assert_response :success
    get "/source/#{incidentProject}/pack2.BaseDistro2.0_LinkedUpdateProject?view=issues"
    assert_response :success
    assert_xml_tag :parent => { tag: 'issue', attributes: { change: 'added' } }, :tag => 'name', :content => '1042'
    assert_xml_tag :parent => { tag: 'issue', attributes: { change: 'added' } }, :tag => 'name', :content => '4201'
    assert_xml_tag :tag => 'kind', :content => 'link'
    Timecop.freeze(1)
    post "/source/#{incidentProject}/patchinfo?cmd=updatepatchinfo"
    assert_response :success
    get "/source/#{incidentProject}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag( :tag => 'category', :content => 'security') # changed due to CVE
    assert_xml_tag( :tag => 'issue', :attributes => { id: '4201', tracker: 'bnc' } )
    get "/source/#{incidentProject}/patchinfo?view=issues"
    assert_response :success
    assert_xml_tag :tag => 'kind', :content => 'patchinfo'
    assert_no_xml_tag :parent => { tag: 'issue' }, :tag => 'issue', :attributes => { change: nil }
    assert_no_xml_tag :parent => { tag: 'issue' }, :tag => 'issue', :attributes => { change: '' }
    assert_xml_tag :parent => { tag: 'issue' }, :tag => 'name', :content => '1042'
    assert_xml_tag :parent => { tag: 'issue' }, :tag => 'tracker', :content => 'bnc'
    assert_xml_tag :parent => { tag: 'issue' }, :tag => 'name', :content => 'CVE-2009-0815'
    assert_xml_tag :parent => { tag: 'issue' }, :tag => 'tracker', :content => 'cve'
    assert_xml_tag :parent => { tag: 'issue' }, :tag => 'name', :content => '4201'
    assert_xml_tag :parent => { tag: 'issue' }, :tag => 'tracker', :content => 'bnc'

    # test that another, new started branch is getting the source changes from this incident in flight
    post '/source/BaseDistro2.0/pack2', :cmd => 'branch', :maintenance => 1
    assert_response :success
    get '/source/home:maintenance_coord:branches:BaseDistro2.0:LinkedUpdateProject/pack2.BaseDistro2.0_LinkedUpdateProject/_history'
    assert_response :success
    assert_xml_tag :tag => 'revisionlist', :children => { count: 2 } # branch & copy from devel
    # ensure that we got the incident package
    get '/source/home:maintenance_coord:branches:BaseDistro2.0:LinkedUpdateProject/pack2.BaseDistro2.0_LinkedUpdateProject/dummy.changes'
    assert_response :success
    # ensure that we got the incident package
    get '/source/home:maintenance_coord:branches:BaseDistro2.0:LinkedUpdateProject/pack2.BaseDistro2.0_LinkedUpdateProject/dummy.changes'
    # cleanup
    delete '/source/home:maintenance_coord:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success

    ### the backend is now building the packages, injecting results
    # run scheduler once to create job file. x86_64 scheduler gets no work
    run_scheduler('x86_64')
    run_scheduler('i586')
    # check build state
    get "/build/#{incidentProject}/_result"
    assert_response :success
    # BaseDistro2.0_BaseDistro2LinkedUpdateProject_repo
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586', state: 'building' } },
               :tag => 'status', :attributes => { package: 'pack2.BaseDistro2.0_LinkedUpdateProject', code: 'scheduled' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586' } },
               :tag => 'status', :attributes => { package: 'pack2.BaseDistro3', code: 'disabled' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586' } },
               :tag => 'status', :attributes => { package: 'pack2.linked.BaseDistro2.0_LinkedUpdateProject', code: 'scheduled' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586' } },
               :tag => 'status', :attributes => { package: 'packNew.BaseDistro2.0_LinkedUpdateProject', code: 'scheduled' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586' } },
               :tag => 'status', :attributes => { package: 'patchinfo', code: 'blocked' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'x86_64', state: 'building' } },
               :tag => 'status', :attributes => { package: 'patchinfo', code: 'excluded' }
    # BaseDistro3_BaseDistro3_repo
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro3', arch: 'i586', state: 'building' } },
               :tag => 'status', :attributes => { package: 'pack2.BaseDistro2.0_LinkedUpdateProject', code: 'disabled' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro3', arch: 'i586' } },
               :tag => 'status', :attributes => { package: 'packNew.BaseDistro2.0_LinkedUpdateProject', code: 'disabled' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro3', arch: 'i586' } },
               :tag => 'status', :attributes => { package: 'pack2.BaseDistro3', code: 'scheduled' }


    # try to create release request too early
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_release">
                                     <source project="' + incidentProject + '" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'build_not_finished' }
    # upload build result as a worker would do
    inject_build_job( incidentProject, 'pack2.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'x86_64')
    inject_build_job( incidentProject, 'pack2.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'i586')
    inject_build_job( incidentProject, 'pack2.linked.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'x86_64')
    inject_build_job( incidentProject, 'pack2.linked.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'i586')
    inject_build_job( incidentProject, 'packNew.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'x86_64')
    inject_build_job( incidentProject, 'packNew.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'i586')
    inject_build_job( incidentProject, 'pack2.BaseDistro3', 'BaseDistro3', 'i586')
    # block patchinfo build
    get "/source/#{incidentProject}/patchinfo/_patchinfo"
    assert_response :success
    pi = ActiveXML::Node.new( @response.body )
    s = pi.add_element 'stopped'
    s.text = 'The issue is not fixed for real yet'
    raw_put "/source/#{incidentProject}/patchinfo/_patchinfo", pi.dump_xml
    assert_response :success
    # collect the job results
    run_scheduler('x86_64')
    run_scheduler('i586')
    wait_for_publisher
    get "/build/#{incidentProject}/_result"
    assert_response :success
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586', state: 'unpublished' } },
               :tag => 'status', :attributes => { package: 'patchinfo', code: 'broken' }
    # try to create release request nevertheless
    raw_post '/request?cmd=create&addrevision=1', '<request>
                                   <action type="maintenance_release">
                                     <source project="' + incidentProject + '" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_xml_tag( :tag => 'status', :attributes => { code: 'build_not_finished' } )
    assert_match(/patchinfo patchinfo is broken/, @response.body)
    # un-block patchinfo build, but filter for an empty result
    pi.delete_element 'stopped'
    pi.add_element('binary').text = 'does not exist'
    raw_put "/source/#{incidentProject}/patchinfo/_patchinfo", pi.dump_xml
    assert_response :success
    # collect the job results
    run_scheduler('x86_64')
    run_scheduler('i586')
    wait_for_publisher
    get "/build/#{incidentProject}/_result"
    assert_response :success
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586', state: 'unpublished' } },
               :tag => 'status', :attributes => { package: 'patchinfo', code: 'failed' }
    # fix it again
    pi.delete_element 'binary'
    raw_put "/source/#{incidentProject}/patchinfo/_patchinfo", pi.dump_xml
    assert_response :success
    # collect the job results
    run_scheduler('x86_64')
    run_scheduler('i586')
    wait_for_publisher
    get "/build/#{incidentProject}/_result"
    assert_response :success
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586', state: 'unpublished' } },
               :tag => 'status', :attributes => { package: 'patchinfo', code: 'succeeded' }
    get "/build/#{incidentProject}/BaseDistro2.0_LinkedUpdateProject/i586/patchinfo/_history"
    assert_response :success

    # check updateinfo
    get "/build/#{incidentProject}/BaseDistro2.0_LinkedUpdateProject/i586/patchinfo/updateinfo.xml"
    assert_response :success
    assert_xml_tag :parent => { tag: 'update', attributes: { from: 'maintenance_coord', status: 'stable', type: 'security', version: '1' } }, :tag => 'id', :content => nil
    assert_xml_tag :tag => 'reference', :attributes => { href: 'https://bugzilla.novell.com/show_bug.cgi?id=1042', id: '1042', type: 'bugzilla' }
    assert_xml_tag :tag => 'reference', :attributes => { href: 'https://bugzilla.novell.com/show_bug.cgi?id=4201', id: '4201', type: 'bugzilla' }
    assert_xml_tag :tag => 'reference', :attributes => { href: 'http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2009-0815', id: 'CVE-2009-0815', type: 'cve' }
    assert_no_xml_tag :tag => 'reference', :attributes => { href: 'https://bugzilla.novell.com/show_bug.cgi?id=' }
    assert_no_xml_tag :tag => 'reference', :attributes => { id: '' }

    # let's say the maintenance guy wants to publish it now
    get "/source/#{incidentProject}/_meta"
    assert_response :success
    maintenance_project_meta = REXML::Document.new(@response.body)
    maintenance_project_meta.elements['/project'].delete_element 'publish'
    raw_put "/source/#{incidentProject}/_meta", maintenance_project_meta.to_s
    assert_response :success
    run_scheduler('x86_64')
    run_scheduler('i586')
    wait_for_publisher
    # is it published?
    get "/published/#{incidentProject}/BaseDistro3/i586/package-1.0-1.i586.rpm"
    assert_response :success
    get "/published/#{incidentProject}/BaseDistro2.0_LinkedUpdateProject/x86_64/package-1.0-1.x86_64.rpm"
    assert_response :success

    # mess up patchinfo and try to create release request
    pi.add_element('binary').text = 'does not exist'
    raw_put "/source/#{incidentProject}/patchinfo/_patchinfo", pi.dump_xml
    assert_response :success
    raw_post '/request?cmd=create&addrevision=1', '<request>
                                   <action type="maintenance_release">
                                     <source project="' + incidentProject + '" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_match(/last patchinfo patchinfo is not yet build/, @response.body)
    # revert
    pi.delete_element 'binary'
    raw_put "/source/#{incidentProject}/patchinfo/_patchinfo", pi.dump_xml
    assert_response :success

    # create release request
    raw_post '/request?cmd=create&addrevision=1', '<request>
                                   <action type="maintenance_release">
                                     <source project="' + incidentProject + '" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_no_xml_tag( :tag => 'source', :attributes => { rev: nil } )
    assert_no_xml_tag( :tag => 'target', :attributes => { project: 'BaseDistro2.0' } ) # BaseDistro2 has an update project, nothing should go to GA project
    assert_no_xml_tag( :tag => 'target', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' } )
    assert_no_xml_tag( :tag => 'target', :attributes => { project: 'BaseDistro3', package: 'pack2' } )
    assert_no_xml_tag( :tag => 'target', :attributes => { project: incidentProject } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2.' + incidentID } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2.linked.' + incidentID } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'packNew.' + incidentID } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'patchinfo.' + incidentID } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'BaseDistro3', package: 'pack2.' + incidentID } )
    assert_xml_tag( :tag => 'target', :attributes => { project: 'BaseDistro3', package: 'patchinfo.' + incidentID } )
    assert_xml_tag( :tag => 'review', :attributes => { by_group: 'test_group' } )
    assert_xml_tag( :tag => 'review', :attributes => { by_user: 'fred' } ) # BaseDistro2:Update pack2
    assert_xml_tag( :tag => 'priority', :content => "important" ) # from patchinfo rating
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)

    # check that changes get still fetched on new branches
    post '/source/BaseDistro2.0/pack2', :cmd => 'branch'
    assert_response :success
    get '/source/home:maintenance_coord:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_history'
    assert_response :success
    assert_xml_tag :tag => 'comment', :content => %r{fetch updates from open incident project #{incidentProject}}
    delete '/source/home:maintenance_coord:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success

    # find the request for the maintenance incident through it's parent (maintenance) project
    get '/request?view=collection&types=maintenance_release&project=My:Maintenance&subprojects=true'
    assert_response :success
    assert_xml_tag( :tag => 'collection', :child => { tag: 'request' } )
    assert_xml_tag( :tag => 'collection', :attributes => { matches: '1' } )

    # validate that request is diffable (not broken)
    post "/request/#{reqid}?cmd=diff"
    assert_response :success

    # source project got locked?
    get "/source/#{incidentProject}/_meta"
    assert_response :success
    assert_xml_tag( :parent => { tag: 'lock' }, :tag => 'enable')
    assert_xml_tag( :parent => { tag: 'access' }, :tag => 'disable', :content => nil ) # but still not out there
    assert_no_xml_tag( :parent => { tag: 'publish' } )
    assert_no_xml_tag( :parent => { tag: 'lock' }, :tag => 'disable') # disable got removed

    # incident project not visible for tom
    login_tom
    raw_post '/request?cmd=create&addrevision=1', '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="' + incidentProject + '" releaseproject="BaseDistro2.0:LinkedUpdateProject" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 404
    # new incident request accept is blocked, but decline works
    login_adrian
    raw_post '/request?cmd=create&addrevision=1', '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="' + incidentProject + '" releaseproject="BaseDistro2.0:LinkedUpdateProject" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    nreqid = node.value(:id)
    prepare_request_with_user 'maintenance_coord', 'power'
    post "/request/#{nreqid}?cmd=changestate&newstate=accepted"
    assert_response 403
    post "/request/#{nreqid}?cmd=changestate&newstate=declined"
    assert_response :success

    # unlock would fail due to open request
    post "/source/#{incidentProject}", { cmd: 'unlock', comment: 'cleanup' }
    assert_response 403
    assert_xml_tag( :tag => 'status', :attributes => { code: 'open_release_request' } )

    # approve review
    login_king
    post "/request/#{reqid}?cmd=changereviewstate&newstate=accepted&by_group=test_group&comment=blahfasel"
    assert_response :success
    post "/request/#{reqid}?cmd=changereviewstate&newstate=accepted&by_user=fred&comment=blahfasel" # default package reviewer
    assert_response :success
    get "/request/#{reqid}"
    assert_response :success
    assert_xml_tag( :parent => { tag: 'state' }, :tag => 'comment', :content => 'blahfasel')

    ActionMailer::Base.deliveries.clear

    # leave a comment
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post create_request_comment_path(id: reqid), 'Release it now!'
      assert_response :success
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal %w(dirkmueller@example.com fred@feuerstein.de test_group@testsuite.org), email.to.sort

    EventSubscription.create eventtype: 'Event::CommentForRequest', receiver_role: :source_maintainer,
                             user: users(:maintenance_assi), receive: true

    # now leave another comment and hope the assi gets it too
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post create_request_comment_path(id: reqid), 'Slave, can you release it? The master is gone'
      assert_response :success
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal %w(dirkmueller@example.com fred@feuerstein.de homer@nospam.net test_group@testsuite.org), email.to.sort

    get comments_request_path(id: reqid)
    assert_xml_tag tag: 'comment', attributes: { who: 'king' }, content: 'Release it now!'

    #### release packages
    # published binaries from incident still exist?
    get "/published/#{incidentProject}/BaseDistro3/i586/package-1.0-1.i586.rpm"
    assert_response :success
    get "/published/#{incidentProject}/BaseDistro2.0_LinkedUpdateProject/x86_64/package-1.0-1.x86_64.rpm"
    assert_response :success
    post "/request/#{reqid}?cmd=changestate&newstate=accepted&comment=releasing"
    assert_response :success
    get "/request/#{reqid}"
    assert_response :success
    assert_xml_tag( :parent => { tag: 'state' }, :tag => 'comment', :content => 'releasing')
    run_scheduler('i586')
    run_scheduler('x86_64')
    wait_for_publisher
    # published binaries from incident got removed?
    get "/published/#{incidentProject}/BaseDistro3/i586/package-1.0-1.i586.rpm"
    assert_response 404
    get "/published/#{incidentProject}/BaseDistro2.0_LinkedUpdateProject/x86_64/package-1.0-1.x86_64.rpm"
    assert_response 404

    # validate result
    get "/source/#{incidentProject}/_meta"
    assert_response :success
    assert_xml_tag( :parent => { tag: 'lock' }, :tag => 'enable') # still locked
    assert_no_xml_tag( :parent => { tag: 'access' }, :tag => 'disable', :content => nil ) # got published, so access got enabled
    get "/source/#{incidentProject}/patchinfo/_meta"
    assert_response :success
    assert_no_xml_tag( :parent => { tag: 'publish' }, :tag => 'enable', :content => nil )
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2/_link'
    assert_response :success
    assert_xml_tag :tag => 'link', :attributes => { project: nil, package: "pack2.#{incidentID}" }
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2?expand=1'
    assert_response :success
    assert_xml_tag( :tag => 'directory', :attributes => { vrev: '2.10' } )
    get "/source/BaseDistro2.0:LinkedUpdateProject/pack2.#{incidentID}"
    assert_response :success
    assert_xml_tag( :tag => 'directory', :attributes => { vrev: '2.10' } )
    get "/source/BaseDistro2.0:LinkedUpdateProject/pack2.#{incidentID}/_link"
    assert_response 404
    get "/source/BaseDistro2.0:LinkedUpdateProject/pack2.linked.#{incidentID}/_link"
    assert_response :success
    assert_xml_tag :tag => 'link', :attributes => { project: nil, package: "pack2.#{incidentID}", cicount: 'copy' }
    get '/source/BaseDistro2.0:LinkedUpdateProject/patchinfo'
    assert_response 404
    get "/source/BaseDistro2.0:LinkedUpdateProject/patchinfo.#{incidentID}"
    assert_response :success
    get "/source/BaseDistro2.0:LinkedUpdateProject/patchinfo.#{incidentID}/_patchinfo"
    assert_response :success
    assert_xml_tag :tag => 'patchinfo', :attributes => { incident: incidentID }
    assert_xml_tag :tag => 'packager', :content => 'maintenance_coord'
    get '/build/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586'
    assert_response :success
    get "/build/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/patchinfo.#{incidentID}"
    assert_response :success
    assert_xml_tag :tag => 'binary', :attributes => { filename: 'updateinfo.xml' }
    get "/build/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/patchinfo.#{incidentID}/updateinfo.xml"
    assert_response :success
    # check for changed updateinfoid 
    assert_xml_tag :parent => { tag: 'update', attributes: { from: 'maintenance_coord', status: 'stable', type: 'security', version: '1' } }, :tag => 'id', :content => "My-oldname-#{Time.now.utc.year.to_s}-1"
    # check :full tree
    get '/build/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/_repository'
    assert_response :success
    assert_xml_tag :parent => { tag: 'binarylist' },  :tag => 'binary', :attributes => { filename: 'package.rpm' }
    get '/source/BaseDistro2.0:LinkedUpdateProject/_project/_history'
    assert_response :success
    assert_xml_tag :parent => { tag: 'revision' },  :tag => 'comment', :content => "Releasing from project My:Maintenance:#{incidentID} the update My-oldname-2010-1"
    get "/source/BaseDistro2.0:LinkedUpdateProject/patchinfo.#{incidentID}/_meta"
    assert_response :success
    # must not build in Update project
    assert_no_xml_tag( :parent => { tag: 'build' }, :tag => 'enable')
    # must be published in Update project
    assert_xml_tag( :parent => { tag: 'publish' }, :tag => 'enable', :attributes => { repository: nil, arch: nil } )
    get "/source/BaseDistro2.0:LinkedUpdateProject/pack2.#{incidentID}/_meta"
    assert_response :success
    # must not build in Update project
    assert_no_xml_tag( :parent => { tag: 'build' }, :tag => 'enable')
    # must be published only via patchinfos
    assert_no_xml_tag( :parent => { tag: 'publish' }, :tag => 'enable')

    # no maintenance trigger exists anymore
    get "/source/#{incidentProject}/_meta"
    assert_response :success
    assert_no_xml_tag :tag => 'releasetarget', :attributes => { trigger: 'maintenance' }

    # search will find this incident not anymore
    get '/search/project', :match => '[repository/releasetarget/@trigger="maintenance"]'
    assert_response :success
    assert_no_xml_tag :parent => { tag: 'collection' },  :tag => 'project', :attributes => { name: incidentProject }

    # check released data
    wait_for_publisher
    get '/build/BaseDistro2.0:LinkedUpdateProject/_result'
    assert_response :success
    assert_xml_tag :tag => 'result', :attributes => { repository: 'BaseDistro2LinkedUpdateProject_repo', arch: 'i586', state: 'published' }
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586'
    assert_response :success
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/delete_me-1.0-1.i586.rpm'
    assert_response :success
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/package-1.0-1.i586.rpm'
    assert_response :success
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/package-1.0-1.i586.rpm?view=fileinfo'
    assert_response :success
    assert_xml_tag :tag => 'name', :content => 'package'
    assert_xml_tag :tag => 'version', :content => '1.0'
    assert_xml_tag :tag => 'release', :content => '1'
    assert_xml_tag :tag => 'arch', :content => 'i586'
    assert_xml_tag :tag => 'summary', :content => 'Test Package'
    assert_xml_tag :tag => 'size', :content => '2263'
    assert_xml_tag :tag => 'description'
    assert_xml_tag :tag => 'mtime'
    hashed=node=nil
    IO.popen("gunzip -cd #{Rails.root}/tmp/backend_data/repos/BaseDistro2.0:/LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/repodata/*-updateinfo.xml.gz") do |io|
       node = REXML::Document.new( io.read )
    end
    assert_equal "My-oldname-#{Time.now.year}-1", node.elements['/updates/update/id'].first.to_s
    # verify meta data created by createrepo
    IO.popen("gunzip -cd #{Rails.root}/tmp/backend_data/repos/BaseDistro2.0:/LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/repodata/*-primary.xml.gz") do |io|
       hashed = Xmlhash.parse(io.read)
    end
    pac = nil
    hashed.elements('package') do |p|
      next unless p['name'] == 'package'
      next unless p['arch'] == 'x86_64'
      pac = p
    end
    assert_not_nil pac
    assert_equal 'GPLv2+', pac['format']['rpm:license']
    assert_equal 'Development/Tools/Building', pac['format']['rpm:group']
    assert_equal 'package-1.0-1.src.rpm', pac['format']['rpm:sourcerpm']
    assert_equal '2132', pac['format']['rpm:header-range']['end']
    assert_equal '280', pac['format']['rpm:header-range']['start']
    assert_equal 'bash', pac['format']['rpm:requires']['rpm:entry']['name']
    assert_equal 'myself', pac['format']['rpm:provides']['rpm:entry'][0]['name']
    assert_equal 'package', pac['format']['rpm:provides']['rpm:entry'][1]['name']
    assert_equal 'package(x86-64)', pac['format']['rpm:provides']['rpm:entry'][2]['name']
    assert_equal 'something', pac['format']['rpm:conflicts']['rpm:entry']['name']
    assert_equal 'old_crap', pac['format']['rpm:obsoletes']['rpm:entry']['name']
    if File.exist? '/var/adm/fillup-templates'
      # seems to be a SUSE system
      if pac['format']['rpm:suggests'].nil?
        print 'createrepo seems not to create week dependencies, we want this on SUSE systems'
      end 
      assert_equal 'pure_optional', pac['format']['rpm:suggests']['rpm:entry']['name']
      assert_equal 'would_be_nice', pac['format']['rpm:recommends']['rpm:entry']['name']
      assert_equal 'other_package_likes_it', pac['format']['rpm:supplements']['rpm:entry']['name']
      assert_equal 'other_package', pac['format']['rpm:enhances']['rpm:entry']['name']
    else
      puts "WARNING: some tests are skipped on non-SUSE systems. rpmmd meta data may not be complete."
    end
    # file lists
    IO.popen("gunzip -cd #{Rails.root}/tmp/backend_data/repos/BaseDistro2.0:/LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/repodata/*-filelists.xml.gz") do |io|
       hashed = Xmlhash.parse(io.read)
    end
    #STDERR.puts JSON.pretty_generate(hashed)
    assert hashed['package'].map{|f| f['file']}.include? '/my_packaged_file'
    # master tags
    IO.popen("cat #{Rails.root}/tmp/backend_data/repos/BaseDistro2.0:/LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/repodata/repomd.xml") do |io|
       hashed = Xmlhash.parse(io.read)
    end
    found=nil
    hashed["data"].each do |d|
      found=true if d["type"] == "updateinfo"
    end
    assert_equal found, true
    # modifyrepo tends to kill that one:
    if File.exist? '/var/adm/fillup-templates'
      # seems to be a SUSE system
      assert_equal hashed["tags"]["repo"], "obsrepository://obstest/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo"
    end

    # verify that local linked packages still get branched correctly
    post '/source/BaseDistro2.0/pack2', :cmd => 'branch'
    assert_response :success
    get '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
    get '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_link'
    assert_response :success
    assert_xml_tag :tag => 'link', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: nil }
    get '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject/pack2.linked/_link'
    assert_response :success
    assert_xml_tag :tag => 'link', :attributes => { project: nil, package: 'pack2' }
    delete '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success

    # revoke a release update
    delete '/source/BaseDistro2.0:LinkedUpdateProject/pack2'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/pack2.linked'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/packNew'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/packNew.0'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/pack2.0'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/pack2.linked.0'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/patchinfo.0'
    assert_response :success
    run_scheduler('i586')
    get '/build/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/_repository'
    assert_response :success
    assert_no_xml_tag :parent => { tag: 'binarylist' },  :tag => 'binary'
    # publish repo got cleaned
    wait_for_publisher
    get '/build/BaseDistro2.0:LinkedUpdateProject/_result'
    assert_response :success
    # it is unpublished, because api does not see a single published package. this still verifies that repo is not in intermediate state anymore.
    assert_xml_tag :tag => 'result', :attributes => { repository: 'BaseDistro2LinkedUpdateProject_repo', arch: 'i586', state: 'unpublished' }
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586'
    assert_response :success
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/delete_me-1.0-1.i586.rpm'
    assert_response 404
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/package-1.0-1.i586.rpm'
    assert_response 404

    # disable lock and verify meta
    delete "/source/#{incidentProject}"
    assert_response 403
    post "/source/#{incidentProject}", { cmd: 'unlock', comment: 'cleanup' }
    assert_response :success
    get "/source/#{incidentProject}/_meta"
    assert_response :success
    assert_xml_tag :tag => 'releasetarget', :attributes => { trigger: 'maintenance' }

    # cleanup
    delete "/source/#{incidentProject}"
    assert_response :success
    delete '/source/BaseDistro3/pack2.0'
    assert_response :success
    # don't leave the broken link and just recreate it
    Suse::Backend.delete '/source/BaseDistro3/pack2?user=king'
    assert_response :success
    p = Package.find_by_project_and_name('BaseDistro3', 'pack2')
    Suse::Backend.put( '/source/BaseDistro3/pack2/_meta?user=king', p.to_axml)
    raw_put '/source/BaseDistro3/pack2/package.spec', File.open("#{Rails.root}/test/fixtures/backend/binary/package.spec").read
    assert_response :success
  end

  def test_create_invalid_patchinfo
    login_tom
    # collons in patchinfo names are not allowed but common mistake
    post '/source/home:tom?cmd=createpatchinfo&force=1&name=home:tom'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'invalid_package_name' }
  end

  def test_create_invalid_submit_request
    login_tom
    # submit requests are not allowed against release projects
    post '/request?cmd=create', '<request>
                                   <action type="submit">
                                     <source project="BaseDistro2.0" package="pack2" rev="0" />
                                     <target project="BaseDistro2.0:LinkedUpdateProject" package="pack2" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'submit_request_rejected' }
    assert_match(/is a maintenance release project/, @response.body)
  end

  def test_create_invalid_incident_request
    login_tom
    # without specifing target, the default target must get found via attribute
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom" />
                                     <target project="home:tom" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'no_maintenance_project' }

    # submit foreign package without releaseproject
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="My:Maintenance" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'no_maintenance_release_target' }

    # submit foreign package with wrong releaseproject
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="home:tom" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'no_maintenance_release_target' }
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="NOT_EXISTING" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 404
    assert_xml_tag :tag => 'status', :attributes => { code: 'unknown_project' }
  end

  def test_create_invalid_release_request
    login_tom
    # branch a package with simple branch command (not mbranch)
    post '/source/BaseDistro/pack1', :cmd => :branch
    assert_response :success
    # check source link
    get '/source/home:tom:branches:BaseDistro:Update/pack1/_link'
    assert_response :success
    # some change
    put '/source/home:tom:branches:BaseDistro:Update/pack1/file', "file"
    assert_response :success
    # remove release target
    get '/source/home:tom:branches:BaseDistro:Update/_meta'
    assert_response :success
    pi = REXML::Document.new( @response.body )
    pi.elements['//repository'].delete_element 'releasetarget'
    put '/source/home:tom:branches:BaseDistro:Update/_meta', pi.to_s
    assert_response :success

    # Run without server side expansion
    prepare_request_with_user 'maintenance_coord', 'power'
    rq = '<request>
           <action type="maintenance_release">
             <source project="home:tom:branches:BaseDistro:Update" package="pack1" />
             <target project="BaseDistro:Update" package="pack1" />
           </action>
           <state name="new" />
         </request>'
    post '/request?cmd=create', rq
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'repository_without_releasetarget' }


    # try with server side request expansion
    rq = '<request>
           <action type="maintenance_release">
             <source project="home:tom:branches:BaseDistro:Update" />
           </action>
           <state name="new" />
         </request>'
    post '/request?cmd=create', rq
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'wrong_linked_package_source' }

    # add a release target
    login_tom
    get '/source/home:tom:branches:BaseDistro:Update/_meta'
    assert_response :success
    meta = REXML::Document.new( @response.body )
    meta.elements['//repository'].add_element 'releasetarget'
    meta.elements['//releasetarget'].add_attribute REXML::Attribute.new('project', 'BaseDistro:Update')
    meta.elements['//releasetarget'].add_attribute REXML::Attribute.new('repository', 'BaseDistroUpdateProject_repo')
    put '/source/home:tom:branches:BaseDistro:Update/_meta', meta.to_s
    assert_response :success

    # retry
    prepare_request_with_user 'maintenance_coord', 'power'
    post '/request?cmd=create', rq
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'missing_patchinfo' }

    # add required informations about the update
    login_tom
    post '/source/home:tom:branches:BaseDistro:Update?cmd=createpatchinfo'
    assert_response :success
    post '/source/home:tom:branches:BaseDistro:Update?cmd=createpatchinfo&name=pack1'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'package_already_exists' }
    post '/source/home:tom:branches:BaseDistro:Update?cmd=createpatchinfo'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'patchinfo_file_exists' }
    post '/source/home:tom:branches:BaseDistro:Update?cmd=createpatchinfo&force=1'
    assert_response :success

    prepare_request_with_user 'maintenance_coord', 'power'
    post '/request?cmd=create', rq
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'build_not_finished' }

    # _patchinfo still incomplete
    prepare_request_with_user 'maintenance_coord', 'power'
    post '/request?cmd=create&ignore_build_state=1', rq
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'incomplete_patchinfo' }

    # fix patchinfo
    login_tom
    get '/source/home:tom:branches:BaseDistro:Update/patchinfo/_patchinfo'
    assert_response :success
    pi = REXML::Document.new( @response.body )
    pi.elements['//summary'].text = 'My Summary'
    put '/source/home:tom:branches:BaseDistro:Update/patchinfo/_patchinfo', pi.to_s
    assert_response :success

    # remove architecture
    meta.elements['//repository'].delete_element 'arch'
    put '/source/home:tom:branches:BaseDistro:Update/_meta', meta.to_s
    assert_response :success

    prepare_request_with_user 'maintenance_coord', 'power'
    post '/request?cmd=create&ignore_build_state=1', rq
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'repository_without_architecture' }

    # add a wrong architecture
    login_tom
    meta.elements['//repository'].add_element 'arch'
    meta.elements['//arch'].text = 'ppc'
    put '/source/home:tom:branches:BaseDistro:Update/_meta', meta.to_s
    assert_response :success

    prepare_request_with_user 'maintenance_coord', 'power'
    post '/request?cmd=create&ignore_build_state=1', rq
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'architecture_order_missmatch' }

    # cleanup
    login_tom
    delete '/source/home:tom:branches:BaseDistro:Update'
    assert_response :success
  end

  def test_validate_evergreen_reviewers
    # Evergreen is an on-top project to our official Update project.
    # While the official one is using reviewers, the evergreen is linking
    # to it, but does not want to use reviewers

    # add temporary reviewer
    login_king
    get '/source/BaseDistro:Update/_meta'
    assert_response :success
    meta = originmeta = ActiveXML::Node.new( @response.body )
    meta.add_element 'person', { userid: 'adrian', role: 'reviewer' }
    put '/source/BaseDistro:Update/_meta', meta.dump_xml
    assert_response :success

    # ensure target package exists
    get '/source/BaseDistro:Update/pack2/_meta'
    assert_response :success

    login_tom
    # create project
    put '/source/home:tom:EVERGREEN/_meta', "<project name='home:tom:EVERGREEN'> <title/> <description/>
                                         <link project='BaseDistro:Update'/>
                                         <repository name='dummy'>
                                           <releasetarget project='BaseDistro:Update' repository='BaseDistroUpdateProject_repo' trigger='maintenance' />
                                           <arch>i586</arch>
                                          </repository>
                                        </project>"
    assert_response :success
    post '/source/home:tom:EVERGREEN/_attribute', "<attributes><attribute namespace='OBS' name='BranchTarget' /></attributes>"
    assert_response :success
    # create package
    put '/source/home:tom:EVERGREEN/pack/_meta', "<package name='pack'> <title/> <description/> </package>"
    assert_response :success

    # create release request with default reviewer
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:EVERGREEN" package="pack" />
                                     <target project="BaseDistro:Update" package="pack2" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag :tag => 'review'
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)
    # revoke to unlock the source
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # create release request WITHOUT default reviewer
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:EVERGREEN" package="pack" />
                                     <target project="home:tom:EVERGREEN" package="pack2" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_no_xml_tag :tag => 'review'
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)
    # revoke to unlock the source
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # but get reviewer added if defined in own project
    login_king
    put '/source/home:tom:EVERGREEN/pack2/_meta', "<package name='pack2'> <title/> <description/> <person userid='adrian' role='reviewer' /> </package>"
    assert_response :success
    login_tom
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:EVERGREEN" package="pack" />
                                     <target project="home:tom:EVERGREEN" package="pack2" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag :tag => 'review'
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)
    # revoke to unlock the source
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    #cleanup
    login_king
    put '/source/BaseDistro:Update/_meta', originmeta.dump_xml
    assert_response :success
    delete '/source/home:tom:EVERGREEN'
    assert_response :success
  end

  def test_try_to_release_without_permissions_binary_permissions
    login_tom
    # create project without trigger
    put '/source/home:tom:test/_meta', "<project name='home:tom:test'> <title/> <description/>
                                         <repository name='dummy'>
                                           <releasetarget project='BaseDistro' repository='BaseDistro_repo' />
                                           <arch>i586</arch>
                                          </repository>
                                        </project>"
    assert_response :success
    # add trigger
    put '/source/home:tom:test/_meta', "<project name='home:tom:test'> <title/> <description/>
                                         <repository name='dummy'>
                                           <releasetarget project='BaseDistro' repository='BaseDistro_repo' trigger='maintenance' />
                                           <arch>i586</arch>
                                          </repository>
                                        </project>"
    assert_response :success
    get '/source/home:tom:test/_meta'
    assert_response :success
    assert_xml_tag(:tag => 'releasetarget', :attributes => { trigger: 'maintenance' })
    # create package
    put '/source/home:tom:test/pack/_meta', "<package name='pack'> <title/> <description/> </package>"
    assert_response :success

    # create release request
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:test" package="pack" />
                                     <target project="home:tom:test" package="pack" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)

    # fail ...
    post "/request/#{reqid}?cmd=changestate&newstate=accepted"
    assert_response 403
    assert_xml_tag :tag => 'status', :attributes => { code: 'release_target_no_permission' }

    # create another request with same target must be blocked
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:test" package="pack" />
                                     <target project="home:tom:test" package="pack" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response 400
    assert_xml_tag :tag => 'status', :attributes => { code: 'open_release_requests' }

    # revoke to unlock the source
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # cleanup 
    delete '/source/home:tom:test'
    assert_response :success
  end

  def test_try_to_release_without_permissions_source_permissions
    login_tom
    # create project
    put '/source/home:tom:test/_meta', "<project name='home:tom:test'> <title/> <description/> </project>"
    assert_response :success
    put '/source/home:tom:test/pack/_meta', "<package name='pack'> <title/> <description/> </package>"
    assert_response :success

    # create release request
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:test" package="pack" />
                                     <target project="BaseDistro" package="pack" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)

    # got locked
    get '/source/home:tom:test/_meta'
    assert_response :success
    assert_xml_tag( :parent => { tag: 'lock' }, :tag => 'enable')
    assert_no_xml_tag( :parent => { tag: 'lock' }, :tag => 'disable') # disable got removed

    # fail ...
    post "/request/#{reqid}?cmd=changestate&newstate=accepted"
    assert_response 403
    assert_xml_tag :tag => 'status', :attributes => { code: 'post_request_no_permission' }

    # revoke request, must unlock the incident
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # disable lock and cleanup 
    get '/source/home:tom:test/_meta'
    assert_response :success
    assert_no_xml_tag( :parent => { tag: 'lock' }, :tag => 'enable')

    # cleanup
    delete '/source/home:tom:test'
    assert_response :success
  end

  def last_revision(axml)
    axml.each('revision').last
  end
  
  def test_copy_project_for_release
    # temporary lock the project to validate copy
    login_king
    post '/source/BaseDistro?cmd=set_flag&flag=lock&status=enable'
    assert_response :success

    # as user
    login_tom
    get '/source/BaseDistro/pack1/_meta'
    assert_response :success
    assert_xml_tag :tag => 'disable', :parent => { tag: 'useforbuild' }
    get '/source/BaseDistro/pack2/_meta'
    assert_response :success
    get '/source/BaseDistro/pack3/_meta'
    assert_response :success
    assert_xml_tag :tag => 'bcntsynctag', :content => 'pack1'
    post '/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro'
    assert_response 403
    post '/source/home:tom:CopyOfBaseDistro?cmd=copy&oproject=BaseDistro'
    assert_response :success
    get '/source/home:tom:CopyOfBaseDistro/_meta'
    assert_response :success
    assert_no_xml_tag :tag => 'path'
    assert_no_xml_tag :tag => 'lock'
    delete '/source/home:tom:CopyOfBaseDistro'
    assert_response :success

    # as admin
    login_king
    post '/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&nodelay=1'
    assert_response :success
    get '/source/CopyOfBaseDistro'
    assert_response :success
    assert_xml_tag(:tag => 'directory', :attributes => { count: '6' })
    assert_xml_tag(:tag => 'entry', :attributes => { name: '_product' })
    assert_xml_tag(:tag => 'entry', :attributes => { name: '_product:fixed-release' })
    assert_xml_tag(:tag => 'entry', :attributes => { name: 'patchinfo' })
    assert_xml_tag(:tag => 'entry', :attributes => { name: 'pack1' })
    assert_xml_tag(:tag => 'entry', :attributes => { name: 'pack2' })
    assert_xml_tag(:tag => 'entry', :attributes => { name: 'pack3' })
    # do not crasah on second copy
    post '/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&nodelay=1'
    assert_response :success
    get '/source/CopyOfBaseDistro/_meta'
    assert_response :success
    assert_no_xml_tag :tag => 'path'
    assert_no_xml_tag :tag => 'lock'
    get '/source/CopyOfBaseDistro/_config'
    assert_response :success
    assert_match %r{Repotype: rpm-md-legacy}, @response.body
    get '/source/BaseDistro'
    assert_response :success
    opackages = ActiveXML::Node.new(@response.body)
    get '/source/CopyOfBaseDistro'
    assert_response :success
    packages = ActiveXML::Node.new(@response.body)
    assert_equal opackages.dump_xml, packages.dump_xml

    # compare package meta
    get '/source/CopyOfBaseDistro/pack1/_meta'
    assert_response :success
    assert_xml_tag(:parent => { tag: 'useforbuild' }, :tag => 'disable')
    get '/source/CopyOfBaseDistro/pack3/_meta'
    assert_response :success
    assert_xml_tag(:tag => 'bcntsynctag', :content => 'pack1')
    # compare revisions
    get '/source/BaseDistro/pack2/_history'
    assert_response :success
    history = ActiveXML::Node.new(@response.body)
    srcmd5 = last_revision(history).value(:srcmd5)
    version = last_revision(history).value(:version)
    time = last_revision(history).value(:time)
    vrev = last_revision(history).value(:vrev)
    assert_not_nil srcmd5
    get '/source/CopyOfBaseDistro/pack2/_history'
    assert_response :success
    copyhistory = ActiveXML::Node.new(@response.body)
    copysrcmd5 = last_revision(copyhistory).value(:srcmd5)
    copyversion = last_revision(copyhistory).value(:version)
    copytime = last_revision(copyhistory).value(:time)
    #copyrev = last_revision(copyhistory).rev
    copyvrev = last_revision(copyhistory).value(:vrev)
    assert_equal srcmd5, copysrcmd5
    assert_equal vrev.to_i, copyvrev.to_i - 1  #the copy gets always an additional commit
    assert_equal version, copyversion
    assert_not_equal time, copytime
    assert_equal last_revision(copyhistory).value(:user), 'king'

    # cleanup and unlock
    delete '/source/CopyOfBaseDistro'
    assert_response :success
    post '/source/BaseDistro?cmd=unlock&comment=asd'
    assert_response :success
  end

  def test_copy_project_with_history_and_binaries
    login_tom
    post '/source/home:tom:CopyOfBaseDistro3?cmd=copy&oproject=BaseDistro3&withbinaries=1'
    assert_response 403
    assert_xml_tag :tag => 'status', :attributes => { code: 'project_copy_no_permission' }

    # as admin
    login_king

    # not needed for runnning this test case alone, but another test case might have triggered
    # a build job, so we need to be sure to have no reason to schedule a build
    get '/build/BaseDistro3/BaseDistro3_repo/i586/pack2/_history'
    xml = Xmlhash.parse(@response.body)
    md5 = xml['entry']['srcmd5']
    post "/source/BaseDistro3/pack2?cmd=copy&orev=#{md5}&oproject=BaseDistro3&opackage=pack2"
    assert_response :success
    run_scheduler('i586')

    get '/build/BaseDistro3/_result'
    assert_response :success
    assert_xml_tag :tag => 'status', :attributes => { package: 'pack2', code: 'succeeded' }

    sleep 1 # to ensure that the timestamp becomes newer
    post '/source/CopyOfBaseDistro3?cmd=copy&oproject=BaseDistro3&withhistory=1&withbinaries=1&nodelay=1'
    assert_response :success
    get '/source/CopyOfBaseDistro3/_meta'
    assert_response :success
    get '/source/BaseDistro3'
    assert_response :success
    opackages = ActiveXML::Node.new(@response.body)
    get '/source/CopyOfBaseDistro3'
    assert_response :success
    packages = ActiveXML::Node.new(@response.body)
    assert_equal opackages.to_s, packages.to_s

    # compare revisions
    get '/source/BaseDistro3/pack2/_history'
    assert_response :success
    history = ActiveXML::Node.new(@response.body)
    srcmd5 = last_revision(history).value(:srcmd5)
    version = last_revision(history).value(:version)
    time = last_revision(history).value(:time)
    vrev = last_revision(history).value(:vrev)
    assert_not_nil srcmd5
    get '/source/CopyOfBaseDistro3/pack2/_history'
    assert_response :success
    copyhistory = ActiveXML::Node.new(@response.body)
    copysrcmd5 = last_revision(copyhistory).value(:srcmd5)
    copyversion = last_revision(copyhistory).value(:version)
    copytime = last_revision(copyhistory).value(:time)
    #copyrev = last_revision(copyhistory).rev
    copyvrev = last_revision(copyhistory).value(:vrev)
    assert_equal srcmd5, copysrcmd5
    assert_equal vrev.to_i, copyvrev.to_i  #the copy gets equal vrev
    assert_equal version, copyversion
    assert_not_equal time, copytime # the timestamp got not copied
    assert_equal last_revision(copyhistory).value(:user), 'king'

    # compare binaries
    run_scheduler('i586')
    get '/build/BaseDistro3/BaseDistro3_repo/i586/pack2'
    assert_response :success
    assert_xml_tag :tag => 'binary', :attributes => { filename: 'package-1.0-1.i586.rpm' }
    orig = @response.body
    get '/build/CopyOfBaseDistro3/BaseDistro3_repo/i586/pack2'
    assert_response :success
    assert_equal orig, @response.body

    # verify scheduler state
    get '/build/BaseDistro3/_result'
    assert_response :success
    assert_xml_tag :tag => 'status', :attributes => { package: 'pack2', code: 'succeeded' }
    get '/build/CopyOfBaseDistro3/_result'
    assert_response :success
    assert_xml_tag :tag => 'status', :attributes => { package: 'pack2', code: 'succeeded' }

    delete '/source/CopyOfBaseDistro3'
    assert_response :success
  end

  def test_copy_project_for_release_with_history
    # this is changing also the source project
    login_tom
    post '/source/home:tom:CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&makeolder=1'
    assert_response 403
    assert_xml_tag :tag => 'status', :attributes => { code: 'cmd_execution_no_permission' }
    assert_match(/requires modification permission in oproject/, @response.body)

    # store revisions before copy
    get '/source/BaseDistro/pack2/_history'
    assert_response :success
    originhistory = ActiveXML::Node.new(@response.body)
    last = originhistory.each('revision').last
    originsrcmd5 = last.value(:srcmd5)
    originversion = last.value(:version)
    origintime = last.value('time')
    originvrev = last.value('vrev')
    assert_not_nil originsrcmd5

    # as admin
    login_king
    post '/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&withhistory=1&makeolder=1&nodelay=1'
    assert_response :success
    get '/source/CopyOfBaseDistro/_meta'
    assert_response :success
    get '/source/BaseDistro'
    assert_response :success
    opackages = ActiveXML::Node.new(@response.body)
    get '/source/CopyOfBaseDistro'
    assert_response :success
    packages = ActiveXML::Node.new(@response.body)
    assert_equal opackages.to_s, packages.to_s

    # compare revisions of source project
    get '/source/BaseDistro/pack2/_history'
    assert_response :success
    history = ActiveXML::Node.new(@response.body)
    srcmd5 = last_revision(history).value(:srcmd5)
    version = last_revision(history).value(:version)
    time = last_revision(history).value(:time)
    #rev = last_revision(history).rev
    vrev = last_revision(history).value(:vrev)
    assert_not_nil srcmd5
    assert_equal originsrcmd5, srcmd5
    assert_equal originvrev.to_i + 2, vrev.to_i  # vrev jumps two numbers
    assert_equal version, originversion
    assert_not_equal time, origintime
    assert_equal 'king', last_revision(history).value(:user)

    # compare revisions of destination project
    get '/source/CopyOfBaseDistro/pack2/_history'
    assert_response :success
    copyhistory = ActiveXML::Node.new(@response.body)
    copysrcmd5 = last_revision(copyhistory).value(:srcmd5)
    copyversion = last_revision(copyhistory).value(:version)
    copytime = last_revision(copyhistory).value(:time)
    #copyrev = last_revision(copyhistory).rev
    copyvrev = last_revision(copyhistory).value(:vrev)
    assert_equal originsrcmd5, copysrcmd5
    expectedvrev="#{(originvrev.to_i+1).to_s}.1" # the copy gets incremented by one, but also extended to avoid that it can become
    assert_equal expectedvrev, copyvrev    # newer than the origin project at any time later.
    assert_equal originversion, copyversion
    assert_not_equal origintime, copytime
    assert_equal 'king', last_revision(copyhistory).value(:user)

    #cleanup
    delete '/source/CopyOfBaseDistro'
    assert_response :success
  end

end
