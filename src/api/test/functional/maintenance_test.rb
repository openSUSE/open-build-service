# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/ClassLength
require_relative '../test_helper'
require 'source_controller'

class MaintenanceTests < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    stub_request(:post, 'http://bugzilla.novell.com/xmlrpc.cgi').to_timeout
  end

  def test_instantiate_for_service_packs
    login_tom
    # add a new package with defined link target
    put '/source/home:tom:BaseDistro:SP1/_meta', params: '<project name="home:tom:BaseDistro:SP1" kind="maintenance_release">
        <title/> <description/>
        <link project="BaseDistro:Update"/>
        </project>'
    assert_response :success

    post '/source/home:tom:BaseDistro:SP1/pack1', params: { cmd: 'branch', target_project: 'home:tom:Branch', missingok: 1 }
    assert_response :bad_request
    # osc catches this error code and is fallingback to newinstance=1
    assert_xml_tag tag: 'status', attributes: { code: 'not_missing' }

    post '/source/home:tom:BaseDistro:SP1/pack1', params: { cmd: 'branch', target_project: 'home:tom:Branch', newinstance: 1, extend_package_names: 1 }
    assert_response :success
    assert_xml_tag tag: 'data', attributes: { name: 'sourceproject' }, content: 'home:tom:BaseDistro:SP1'

    get '/source/home:tom:Branch/pack1.home_tom_BaseDistro_SP1/_link'
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: 'home:tom:BaseDistro:SP1' }

    post '/source/BaseDistro:Update/pack1', params: { cmd: 'branch', target_project: 'home:tom:Branch', missingok: 1, extend_package_names: 1 }
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'not_missing' }

    delete '/source/home:tom:Branch'
    assert_response :success
    delete '/source/home:tom:BaseDistro:SP1'
    assert_response :success
  end

  def test_create_maintenance_project
    login_tom

    put '/source/home:tom:maintenance/_meta', params: '<project name="home:tom:maintenance" > <title/> <description/> </project>'
    assert_response :success
    put '/source/home:tom:maintenance/_meta', params: '<project name="home:tom:maintenance" kind="maintenance" > <title/> <description/> </project>'
    assert_response :success
    delete '/source/home:tom:maintenance'
    assert_response :success

    # need write permission in maintained project...
    put '/source/home:tom:maintenance/_meta', params: '<project name="home:tom:maintenance" kind="maintenance" > <title/> <description/> <maintenance><maintains project="BaseDistro"/></maintenance> </project>'
    assert_response :forbidden
    assert_xml_tag tag: 'summary', content: 'No write access to maintained project BaseDistro'

    # create one ...
    put '/source/home:tom:maintenance/_meta', params: '<project name="home:tom:maintenance" kind="maintenance" > <title/> <description/> <maintenance><maintains project="home:tom"/></maintenance> </project>'
    assert_response :success
    get '/source/home:tom:maintenance/_meta'
    assert_response :success
    assert_xml_tag tag: 'maintains', attributes: { project: 'home:tom' }

    get '/search/project', params: { match: '[maintenance/maintains/@project="home:tom"]' }
    assert_response :success
    assert_xml_tag tag: 'collection', children: { count: 1 }
    assert_xml_tag tag: 'maintains', attributes: { project: 'home:tom' }

    # cleanup
    delete '/source/home:tom:maintenance'
    assert_response :success

    # search does not find a maintained project anymore
    get '/search/project', params: { match: '[maintenance/maintains/@project="home:tom"]' }
    assert_response :success
    assert_xml_tag tag: 'collection', children: { count: 0 }
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
    post '/source/BaseDistro/pack1', params: { cmd: :branch }
    assert_response :success
    # check source link
    get '/source/home:tom:branches:BaseDistro:Update/pack1/_link'
    assert_response :success
    assert_project 'BaseDistro:Update'

    # branch a package which does exist in update project and even have a devel package defined there
    post '/source/BaseDistro/pack2', params: { cmd: :branch }
    assert_response :success
    # check source link
    get '/source/home:tom:branches:Devel:BaseDistro:Update/pack2/_link'
    assert_response :success
    assert_project 'Devel:BaseDistro:Update'

    # branch a package which does exist in update project and a stage project is defined via project wide devel project
    post '/source/BaseDistro/Pack3', params: { cmd: :branch }
    assert_response :success
    # check source link
    get '/source/home:tom:branches:Devel:BaseDistro:Update/Pack3/_link'
    assert_response :success
    assert_project 'Devel:BaseDistro:Update'

    # branch a package which does not exist in update project, but update project is linked
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2/_meta'
    assert_response :success
    assert_xml_tag(tag: 'package', attributes: { project: 'BaseDistro2.0' })
    post '/source/BaseDistro2.0/pack2', params: { cmd: :branch }
    assert_response :success
    # check source link
    get '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_link'
    assert_response :success
    ret = Xmlhash.parse @response.body
    assert_equal 'BaseDistro2.0:LinkedUpdateProject', ret['project']
    assert_nil ret['package']

    # check if we can upload a link to a packge only exist via project link
    put '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_link', params: @response.body
    assert_response :success

    # cleanup
    login_king
    delete '/source/home:tom:branches:Devel:BaseDistro:Update'
    assert_response :success
    delete '/source/home:tom:branches:BaseDistro:Update'
    assert_response :success
    delete '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
  end

  def test_branch_package_with_local_link
    login_tom

    post '/source/BaseDistro2.0/pack2', params: { cmd: :branch, ignoredevel: 1 }
    assert_response :success

    get '/source/home:tom:branches:BaseDistro2.0/pack2/_meta'
    assert_response :success
    # local linked package got branched as well
    get '/source/home:tom:branches:BaseDistro2.0/pack2.linked/_meta'
    assert_response :success
    assert_xml_tag tag: 'bcntsynctag', content: 'pack2'

    # and trying with extended package names
    delete '/source/home:tom:branches:BaseDistro2.0'
    assert_response :success
    post '/source/BaseDistro2.0/pack2', params: { cmd: :branch, ignoredevel: 1, maintenance: 1 }
    assert_response :success

    get '/source/home:tom:branches:BaseDistro2.0/pack2.BaseDistro2.0/_meta'
    assert_response :success
    # local linked package got branched as well
    get '/source/home:tom:branches:BaseDistro2.0/pack2.linked.BaseDistro2.0/_meta'
    assert_response :success
    assert_xml_tag tag: 'bcntsynctag', content: 'pack2.BaseDistro2.0'

    # cleanup
    delete '/source/home:tom:branches:BaseDistro2.0'
    assert_response :success
  end

  def test_maintenance_request_from_foreign_and_remote_project
    login_king
    # special kdelibs
    put '/source/BaseDistro2.0:LinkedUpdateProject/kdelibs/_meta', params: "<package name='kdelibs'><title/><description/></package>"
    assert_response :success
    put '/source/BaseDistro2.0:LinkedUpdateProject/kdelibs/empty', params: 'NOOP'
    assert_response :success

    login_tom
    # create maintenance request for one package from a unrelated project
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="RemoteInstance:kde4" package="kdelibs" />
                                   </action>
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'remote_source' })
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="BaseDistro2.0:LinkedUpdateProject" />
                                   </action>
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    # note the &lt; inside description to test html encoding for _patchinfo file
    post '/request?cmd=create&addrevision=1', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="RemoteInstance:kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="BaseDistro2.0:LinkedUpdateProject" />
                                   </action>
                                   <description>To fix my &lt;bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id1 = node['id']

    # modify source afterwards, must not appear in target after accept
    login_king
    put '/source/kde4/kdelibs/TEMP_FILE', params: 'dummy'
    assert_response :success
    login_tom

    # validate that request is diffable (not broken)
    post "/request/#{id1}?cmd=diff&view=xml"
    assert_response :success
    # the diffed packages
    assert_xml_tag(tag: 'old', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kdelibs' })
    assert_xml_tag(tag: 'new', attributes: { project: 'RemoteInstance:kde4', package: 'kdelibs' })
    # the expected file transfer
    assert_xml_tag(tag: 'source', attributes: { project: 'RemoteInstance:kde4', package: 'kdelibs' })
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' })
    # diff contains the critical lines
    assert_match(/^-NOOP/, @response.body)
    assert_match(/^\+argl/, @response.body)

    # accept request
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post "/request/#{id1}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success

    get "/request/#{id1}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    incident_project = data.elements['/request/action/target'].attributes.get_attribute('project').to_s

    get "/source/#{incident_project}/kdelibs.BaseDistro2.0_LinkedUpdateProject"
    assert_response :success
    assert_xml_tag(tag: 'linkinfo', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kdelibs' })
    get "/source/#{incident_project}/kdelibs.BaseDistro2.0_LinkedUpdateProject/TEMP_FILE"
    assert_response :not_found

    # no patchinfo was part in source project, got it created ?
    get "/source/#{incident_project}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag tag: 'packager', content: 'tom'
    assert_xml_tag(tag: 'patchinfo', attributes: { incident: '0' })
    assert_xml_tag tag: 'description', content: 'To fix my <bug'

    # again but find update project automatically and use a linked package
    login_tom
    post '/source/kde4/kdelibs', params: { cmd: :branch, ignoredevel: 1 }
    assert_response :success
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="BaseDistro2.0" />
                                     <options>
                                       <sourceupdate>cleanup</sourceupdate>
                                     </options>
                                   </action>
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    # update project extended ?
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id2 = node['id']

    # validate that request is diffable (not broken)
    post "/request/#{id2}?cmd=diff&view=xml"
    assert_response :success
    # the diffed packages
    assert_xml_tag(tag: 'old', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kdelibs' })
    assert_xml_tag(tag: 'new', attributes: { project: 'home:tom:branches:kde4', package: 'kdelibs' })
    # the expected file transfer
    assert_xml_tag(tag: 'source', attributes: { project: 'home:tom:branches:kde4', package: 'kdelibs' })
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' })
    # diff contains the critical lines
    assert_match(/^-NOOP/, @response.body)
    assert_match(/^\+argl/, @response.body)

    # accept request
    prepare_request_with_user('maintenance_coord', 'buildservice')

    # not allowed to remove project
    delete '/source/home:tom:branches:kde4'
    assert_response :forbidden

    post "/request/#{id2}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get "/request/#{id2}"
    assert_response :success
    # package and acceptinfo got added
    assert_xml_tag(tag: 'target', attributes: { package: 'kdelibs.BaseDistro2.0_LinkedUpdateProject' })
    assert_xml_tag(tag: 'acceptinfo')
    post "/request/#{id2}?cmd=diff&view=xml"
    assert_response :success
    # project got cleaned up
    get '/source/home:tom:branches:kde4'
    assert_response :not_found

    get "/request/#{id2}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    incident_project = data.elements['/request/action/target'].attributes.get_attribute('project').to_s

    get "/source/#{incident_project}/kdelibs.BaseDistro2.0_LinkedUpdateProject"
    assert_response :success
    assert_xml_tag(tag: 'linkinfo', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kdelibs' })

    # no patchinfo was part in source project, got it created ?
    get "/source/#{incident_project}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag tag: 'packager', content: 'tom'
    assert_xml_tag tag: 'description', content: 'To fix my bug'
    assert_xml_tag(tag: 'patchinfo', attributes: { incident: '1' })

    # reopen ...
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post "/request/#{id2}?cmd=changestate&newstate=new"
    assert_response :forbidden

    # cleanup
    login_king
    delete '/source/My:Maintenance:0'
    assert_response :success
    delete "/source/#{incident_project}"
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/kdelibs'
    assert_response :success
    delete '/source/kde4/kdelibs/TEMP_FILE'
    assert_response :success
  end

  def test_maintenance_request_enforce_branching
    login_king
    # special kdelibs
    put '/source/BaseDistro2.0:LinkedUpdateProject/kdelibs/_meta', params: "<package name='kdelibs'><title/><description/></package>"
    assert_response :success
    put '/source/BaseDistro2.0:LinkedUpdateProject/kdelibs/empty', params: 'NOOP'
    assert_response :success

    login_tom
    # create maintenance request for one package from a unrelated project
    post '/request?cmd=create&addrevision=1&enforce_branching=1', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="BaseDistro2.0:LinkedUpdateProject" />
                                   </action>
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']
    branch_project = "My:Maintenance:REQUEST:#{reqid}"
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' })
    assert_xml_tag(tag: 'source', attributes: { project: branch_project, package: 'kdelibs.BaseDistro2.0_LinkedUpdateProject' })
    assert_no_xml_tag(tag: 'acceptinfo')
    assert_xml_tag(parent: { tag: 'action', attributes: { type: 'delete' } },
                   tag: 'target', attributes: { project: "My:Maintenance:REQUEST:#{reqid}" })

    # validate that request is diffable (not broken)
    post "/request/#{reqid}?cmd=diff&view=xml"
    assert_response :success
    # the diffed packages
    assert_xml_tag(tag: 'old', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kdelibs' })
    assert_xml_tag(tag: 'new', attributes: { project: branch_project, package: 'kdelibs.BaseDistro2.0_LinkedUpdateProject' })

    get "/source/#{branch_project}/_meta"
    assert_response :success
    assert_xml_tag(tag: 'disable', parent: { tag: 'build' })
    assert_xml_tag(tag: 'disable', parent: { tag: 'publish' })

    get "/source/#{branch_project}/patchinfo/_meta"
    assert_response :success
    assert_xml_tag(tag: 'enable', parent: { tag: 'build' })
    assert_xml_tag(tag: 'enable', parent: { tag: 'publish' })

    get "/source/#{branch_project}/kdelibs.BaseDistro2.0_LinkedUpdateProject/_meta"
    assert_response :success
    assert_xml_tag(tag: 'enable', parent: { tag: 'build' }, attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject' })

    get "/source/#{branch_project}"
    assert_response :success
    assert_xml_tag(tag: 'directory', attributes: { count: '2' })
    get "/source/#{branch_project}/kdelibs.BaseDistro2.0_LinkedUpdateProject/_link"
    assert_response :success
    assert_xml_tag(tag: 'link', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kdelibs' })

    # cleanup
    delete "/source/#{branch_project}"
    assert_response :success
  end

  def test_OBS_BranchTarget
    login_king
    put '/source/ServicePack/_meta', params: "<project name='ServicePack'><title/><description/><link project='kde4'/></project>"
    assert_response :success
    post '/source/ServicePack/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post '/source/ServicePack/_attribute', params: "<attributes><attribute namespace='OBS' name='BranchTarget' /></attributes>"
    assert_response :success

    login_tom
    post '/source', params: { cmd: 'branch', package: 'kdelibs' }
    assert_response :success
    assert_xml_tag tag: 'data', attributes: { name: 'targetproject' }, content: 'home:tom:branches:OBS_Maintained:kdelibs'
    assert_xml_tag tag: 'data', attributes: { name: 'targetpackage' }, content: 'kdelibs.kde4'
    assert_xml_tag tag: 'data', attributes: { name: 'sourceproject' }, content: 'ServicePack'
    assert_xml_tag tag: 'data', attributes: { name: 'sourcepackage' }, content: 'kdelibs'

    # cleanup
    login_king
    delete '/source/ServicePack'
    assert_response :success
    delete '/source/home:tom:branches:OBS_Maintained:kdelibs'
    assert_response :success
  end

  def test_branch_from_service_pack_WIP
    login_king
    put '/source/ServicePack/_meta', params: "<project name='ServicePack'><title/><description/><link project='BaseDistro'/></project>"
    assert_response :success
    # attribute setup
    post '/source/BaseDistro/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post '/source/ServicePack/_attribute', params: "<attributes>
                                               <attribute namespace='OBS' name='Maintained' />
                                            </attributes>"
    assert_response :success

    get '/source/BaseDistro/pack2/_meta'
    assert_response :success
    get '/source/BaseDistro:Update/pack2/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { project: 'BaseDistro:Update', name: 'pack2' }

    post '/source/ServicePack/pack2', params: { cmd: 'branch' }
    assert_response :success

    # default case, work on devel package base
    get '/source/home:king:branches:Devel:BaseDistro:Update/pack2/_link'
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: 'Devel:BaseDistro:Update' }

    # new instance of a package wanted. so we need to link to ServicePack and copy sources from devel
    post '/source/ServicePack/pack2', params: { cmd: 'branch', newinstance: 1 }
    assert_response :success
    get '/source/home:king:branches:ServicePack/pack2/_link'
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: 'ServicePack' }
    get '/source/home:king:branches:ServicePack/pack2/_history'
    assert_response :success
    # we found the new code in update project nevertheless that ServicePack does not link to it
    # and the update package even has a devel area defined here
    assert_xml_tag tag: 'comment', content: 'fetch updates from devel package Devel:BaseDistro:Update/pack2'

    login_king
    delete '/source/ServicePack'
    assert_response :success
    delete '/source/home:king:branches:Devel:BaseDistro:Update'
    assert_response :success
    delete '/source/home:king:branches:ServicePack'
    assert_response :success
  end

  def test_instantiate_new_package_with_local_link_in_service_pack
    login_king
    put '/source/ServicePack/_meta', params: "<project name='ServicePack'><title/><description/><link project='BaseDistro2.0'/> <repository name='ServicePack_repo' /></project>"
    assert_response :success
    put '/source/ServicePack:Update/_meta', params: "<project name='ServicePack:Update' kind='maintenance_release'><title/><description/><link project='ServicePack'/>
          <repository name='ServicePackUpdate_repo'><arch>i586</arch></repository></project>"
    assert_response :success
    post '/source/ServicePack/_attribute', params: "<attributes>
                                               <attribute namespace='OBS' name='UpdateProject'>
                                                 <value>ServicePack:Update</value>
                                               </attribute>
                                            </attributes>"
    assert_response :success

    post '/source/ServicePack/pack2', params: { cmd: 'branch' }
    assert_response :success
    get '/source/ServicePack/pack2/package.spec'
    assert_response :success
    get '/source/ServicePack/pack2/myfile'
    assert_response :success

    # new instance of a package wanted. so we need to link to ServicePack and copy sources from devel
    post '/source', params: { cmd: 'createmaintenanceincident', noaccess: 1 }
    assert_response :success
    # use a fixed count using multiple chars to test regexp stripping the counter number from package names
    MaintenanceIncident.exec_query ['UPDATE incident_counter SET counter = 100 WHERE maintenance_db_project_id = ?', Project.find_by_name('My:Maintenance').id]
    post '/source', params: { cmd: 'createmaintenanceincident', noaccess: 1 }
    assert_response :success
    assert_xml_tag(tag: 'data', attributes: { name: 'targetproject' })
    data = REXML::Document.new(@response.body)
    incident_project = data.elements['/status/data'].text
    assert_equal 'My:Maintenance:100', incident_project

    get '/source/ServicePack:Update/pack2/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { project: 'BaseDistro2.0' } # not in :Update yet
    get '/source/BaseDistro2.0/pack2'
    assert_response :success
    assert_xml_tag(tag: 'directory', attributes: { vrev: '2.5' })

    post '/source/ServicePack:Update/pack2', params: { cmd: 'branch', maintenance: 1, newinstance: 1, target_project: incident_project }
    assert_response :success

    get "/source/#{incident_project}/pack2.ServicePack_Update/_link"
    assert_response :success
    # origin package vrev increased by 1 and extended
    assert_xml_tag(tag: 'link', attributes: { vrev: '3.1', project: 'ServicePack:Update' })
    get "/source/#{incident_project}/pack2.linked.ServicePack_Update/_link"
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: nil, package: 'pack2.ServicePack_Update' }
    get '/source/BaseDistro2.0/pack2'
    assert_response :success
    get "/source/#{incident_project}/pack2.ServicePack_Update/_history"
    assert_response :success
    get "/source/#{incident_project}/pack2.ServicePack_Update"
    assert_response :success
    put "/source/#{incident_project}/pack2.ServicePack_Update/some_new_file", params: 'content change'
    assert_response :success
    put "/source/#{incident_project}/pack2.ServicePack_Update/myfile", params: 'modify existing file'
    assert_response :success

    post '/request?cmd=create&ignore_build_state=1', params: "<request>
                                   <action type='maintenance_release'>
                                     <source project='#{incident_project}' />
                                   </action>
                                   <state name='new' />
                                 </request>"
    assert_response :success
    assert_xml_tag tag: 'target', attributes: { project: 'ServicePack:Update', package: 'pack2.100' }
    assert_xml_tag tag: 'target', attributes: { project: 'ServicePack:Update', package: 'pack2.linked.100' }
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']
    # the local linked package delivers not full content
    post "/request/#{reqid}?cmd=diff&view=xml"
    assert_response :success
    assert_match(/-DummyContent/, @response.body)
    assert_match(/\+modify existing file/, @response.body)
    # verfiy that unchanged file gets not reported
    assert_no_xml_tag tag: 'new', attributes: { name: 'package.spec' }
    assert_xml_tag parent: { tag: 'file', attributes: { state: 'added' } },
                   tag: 'new', attributes:  { name: 'some_new_file' }
    # local link got diffed unexpanded
    assert_xml_tag tag: 'old', attributes:  { package: 'pack2.linked' }
    assert_match(/-&lt;link package="pack2"/, @response.body)
    assert_match(/\+&lt;link package="pack2.ServicePack_Update"/, @response.body)
    # two separate sourcediffs in each action included
    assert_xml_tag child: { tag: 'old', attributes: { project: 'ServicePack:Update', package: 'pack2' } },
                   sibling: { tag: 'target', attributes: { project: 'ServicePack:Update', package: 'pack2.100' } },
                   tag: 'sourcediff'
    assert_xml_tag child: { tag: 'old', attributes: { project: 'ServicePack:Update', package: 'pack2.linked' } },
                   sibling: { tag: 'target', attributes: { project: 'ServicePack:Update', package: 'pack2.linked.100' } },
                   tag: 'sourcediff'

    # revoke to unlock the source
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # cleanup
    login_king
    delete '/source/My:Maintenance:0'
    assert_response :success
    delete "/source/#{incident_project}"
    assert_response :success
    delete '/source/ServicePack:Update'
    assert_response :success
    delete '/source/ServicePack'
    assert_response :success
    delete '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
  end

  def test_mbranch_and_maintenance_entire_project_request
    login_king
    put '/source/ServicePack/_meta', params: "<project name='ServicePack'><title/><description/><link project='kde4'/></project>"
    assert_response :success
    put '/source/ServicePack/_config', params: 'cicntstart: 99.1'
    assert_response :success

    # test right branching from ServicePack layer
    login_tom
    post '/source/ServicePack/kdelibs', params: { cmd: 'branch', maintenance: 1 }
    assert_response :success
    delete '/source/home:tom:branches:kde4/kdelibs.kde4' # .kde4 suffix, not .ServicePack
    assert_response :success

    # setup maintained attributes
    prepare_request_with_user('maintenance_coord', 'buildservice')
    # an entire project
    post '/source/BaseDistro/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    # single packages
    post '/source/BaseDistro2.0/pack2/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post '/source/BaseDistro3/pack2/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post '/source/ServicePack/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success

    # search for maintained packages like osc is doing
    get '/search/package?match=%28%40name+%3D+%27pack2%27%29+and+%28project%2Fattribute%2F%40name%3D%27OBS%3AMaintained%27+or+attribute%2F%40name%3D%27OBS%3AMaintained%27%29'
    assert_response :success
    assert_xml_tag tag: 'collection', children: { count: 3 }

    # do the real mbranch for default maintained packages
    # test it with "noaccess"
    login_tom
    post '/source', params: { cmd: 'branch', package: 'pack2', noaccess: '1' }
    assert_response :success

    # validate result
    get '/source/home:tom:branches:OBS_Maintained:pack2/_meta'
    assert_response :success
    assert_xml_tag(parent: { tag: 'access' }, tag: 'disable', content: nil)
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject/_meta'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update/_meta'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject/_link'
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' }
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update/_link'
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: 'BaseDistro:Update', package: 'pack2' }
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update/_history'
    assert_response :success
    assert_xml_tag tag: 'comment', content: /fetch updates from devel package/
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro3/_link'
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: 'BaseDistro3', package: 'pack2' }
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.linked.BaseDistro2.0_LinkedUpdateProject/_link'
    assert_response :success
    assert_no_xml_tag tag: 'link', attributes: { project: 'BaseDistro2.0' }
    assert_xml_tag tag: 'link', attributes: { package: 'pack2.BaseDistro2.0_LinkedUpdateProject' }

    # test branching another package set into same project
    post '/source', params: { cmd: 'branch', package: 'pack1', target_project: 'home:tom:branches:OBS_Maintained:pack2' }
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack1.BaseDistro_Update'
    assert_response :success

    # add a new package with defined link target
    post '/source/BaseDistro:Update/packN', params: { cmd: 'branch', target_project: 'home:tom:branches:OBS_Maintained:pack2', missingok: 1, extend_package_names: 1 }
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/packN.BaseDistro_Update'
    assert_response :success

    # test branching another package set into same project from same project
    post '/source', params: { cmd: 'branch', package: 'Pack3', target_project: 'home:tom:branches:OBS_Maintained:pack2' }
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/Pack3.BaseDistro_Update'
    assert_response :success
    # test branching another package only reachable via project link into same project
    post '/source', params: { cmd: 'branch', package: 'kdelibs', target_project: 'home:tom:branches:OBS_Maintained:pack2', noaccess: 1 }
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'create_project_no_permission' }

    # FIXME: backend has a bug that it destroys the link even with keeplink if opackage has no rev
    put '/source/home:coolo:test/kdelibs_DEVEL_package/DUMMY', params: 'CONTENT'
    assert_response :success

    # add an issue
    put '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update/dummy.changes', params: 'DUMMY bnc#1042'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro_Update?view=issues'
    assert_response :success
    assert_no_xml_tag parent: { tag: 'issue' }, tag: 'issue', attributes: { change: nil }
    assert_no_xml_tag parent: { tag: 'issue' }, tag: 'issue', attributes: { change: '' }
    assert_xml_tag parent: { tag: 'issue', attributes: { change: 'added' } }, tag: 'name', content: '1042'

    get '/source/home:tom:branches:OBS_Maintained:pack2/_meta'
    assert_response :success
    oldmeta = @response.body
    post '/source', params: { cmd: 'branch', package: 'kdelibs', target_project: 'home:tom:branches:OBS_Maintained:pack2' }
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/kdelibs.kde4/_link'
    assert_response :success
    # Indirect packages need to link and build in update project of former ServicePack, because current ServicePack
    # may introduce more incompatibilities due to changed packages used for building
    assert_xml_tag tag: 'link', attributes: { project: 'kde4', package: 'kdelibs' }

    # do some file changes
    put '/source/home:tom:branches:OBS_Maintained:pack2/kdelibs.kde4/new_file', params: 'new_content_0815'
    assert_response :success
    put '/source/home:tom:branches:OBS_Maintained:pack2/Pack3.BaseDistro_Update/new_file', params: 'new_content_2137'
    assert_response :success

    # validate created project meta
    get '/source/home:tom:branches:OBS_Maintained:pack2/_meta'
    assert_response :success
    assert_xml_tag parent: { tag: 'build' }, tag: 'disable'

    assert_xml_tag parent: { tag: 'repository', attributes: { name: 'BaseDistro2.0_LinkedUpdateProject' } },
                   tag: 'path', attributes: { repository: 'BaseDistro2LinkedUpdateProject_repo', project: 'BaseDistro2.0:LinkedUpdateProject' }
    assert_xml_tag parent: { tag: 'repository', attributes: { name: 'BaseDistro2.0_LinkedUpdateProject' } },
                   tag: 'arch', content: 'i586'

    assert_xml_tag parent: { tag: 'repository', attributes: { name: 'BaseDistro_Update' } },
                   tag: 'path', attributes: { repository: 'BaseDistroUpdateProject_repo', project: 'BaseDistro:Update' }

    assert_xml_tag(tag: 'releasetarget', attributes: { project: 'BaseDistro:Update', repository: 'BaseDistroUpdateProject_repo', trigger: nil })

    assert_xml_tag(tag: 'releasetarget', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', repository: 'BaseDistro2LinkedUpdateProject_repo', trigger: nil })

    # validate created package meta
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { name: 'pack2.BaseDistro2.0_LinkedUpdateProject', project: 'home:tom:branches:OBS_Maintained:pack2' }
    assert_xml_tag parent: { tag: 'build' }, tag: 'enable', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject' }

    # and branch same package again and expect error
    post '/source', params: { cmd: 'branch', package: 'pack1', target_project: 'home:tom:branches:OBS_Maintained:pack2' }
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'double_branch_package' }
    assert_match(/branch target package already exists:/, @response.body)

    # create patchinfo
    post '/source/BaseDistro?cmd=createpatchinfo'
    assert_response :forbidden
    post '/source/home:tom:branches:OBS_Maintained:pack2?cmd=createpatchinfo'
    assert_response :success
    assert_xml_tag(tag: 'data', attributes: { name: 'targetpackage' }, content: 'patchinfo')
    assert_xml_tag(tag: 'data', attributes: { name: 'targetproject' }, content: 'home:tom:branches:OBS_Maintained:pack2')
    get '/source/home:tom:branches:OBS_Maintained:pack2/patchinfo/_meta'
    assert_response :success
    assert_xml_tag parent: { tag: 'build' }, tag: 'enable'
    assert_xml_tag parent: { tag: 'useforbuild' }, tag: 'disable'
    assert_no_xml_tag parent: { tag: 'publish' } # due to noaccess

    # delete kdelibs package again or incident creation will fail since it does not point to a maintained project.
    delete '/source/home:tom:branches:OBS_Maintained:pack2/kdelibs.kde4'
    assert_response :success
    put '/source/home:tom:branches:OBS_Maintained:pack2/_meta', params: oldmeta
    assert_response :success

    # create maintenance request
    # without specifing target, the default target must get found via attribute
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" />
                                     <options>
                                       <sourceupdate>cleanup</sourceupdate>
                                     </options>
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id = node['id']
    assert_xml_tag(tag: 'request', children: { count: 3, only: { tag: 'action' } }) # only with changed sources
    assert_xml_tag(tag: 'source', attributes: { project: 'home:tom:branches:OBS_Maintained:pack2' })
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance' })
    assert_xml_tag(tag: 'target', attributes: { releaseproject: 'BaseDistro:Update' })
    assert_no_xml_tag(tag: 'target', attributes: { releaseproject: 'BaseDistro3' }) # no source change
    assert_no_xml_tag(tag: 'target', attributes: { releaseproject: 'BaseDistro:LinkedUpdateProject' })

    # validate that request is diffable (not broken)
    post "/request/#{id}?cmd=diff&view=xml"
    assert_response :success
    assert_match(/new_content_2137/, @response.body) # check if our changes are part of the diff

    # store data for later checks
    get '/source/home:tom:branches:OBS_Maintained:pack2/_meta'
    assert_response :success
    oprojectmeta = Xmlhash.parse(@response.body)

    get '/source/home:tom:branches:OBS_Maintained:pack2/_meta'
    assert_response :success
    assert_xml_tag(parent: { tag: 'access' }, tag: 'disable', content: nil)

    # switch user, still diffable
    prepare_request_with_user('maintenance_coord', 'buildservice')
    get '/source/home:tom:branches:OBS_Maintained:pack2/_meta'
    assert_response :not_found # due to noaccess
    post "/request/#{id}?cmd=diff&view=xml"
    assert_response :success
    assert_match(/new_content_2137/, @response.body) # check if our changes are part of the diff

    # accept request
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    get "/request/#{id}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    incident_project = data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    assert_not_equal incident_project, 'My:Maintenance'

    # validate cleanup
    get '/source/home:tom:branches:OBS_Maintained:pack2'
    assert_response :not_found

    # validate created project
    get "/source/#{incident_project}/_meta"
    assert_response :success
    assert_xml_tag(parent: { tag: 'build' }, tag: 'disable', content: nil)
    assert_xml_tag(parent: { tag: 'access' }, tag: 'disable', content: nil)
    node = Xmlhash.parse(@response.body)
    # repository definition must be the same, except for the maintenance trigger
    node.elements('repository') do |r|
      rt = r['releasetarget']
      assert_not_nil rt
      assert_equal 'maintenance', rt['trigger']
      rt.delete('trigger')
    end
    assert_equal node.elements('repository').first.to_s, oprojectmeta.elements('repository').first.to_s
    assert_equal node.elements('build').first.to_s, oprojectmeta.elements('build').first.to_s

    get "/source/#{incident_project}"
    assert_response :success
    assert_xml_tag(tag: 'directory', attributes: { count: '3' })

    get "/source/#{incident_project}/pack2.BaseDistro_Update/_meta"
    assert_response :success
    assert_xml_tag(tag: 'enable', parent: { tag: 'build' }, attributes: { repository: 'BaseDistro_Update' })

    get "/source/#{incident_project}/pack2.BaseDistro_Update?view=issues"
    assert_response :success
    assert_no_xml_tag parent: { tag: 'issue' }, tag: 'issue', attributes: { change: nil }
    assert_no_xml_tag parent: { tag: 'issue' }, tag: 'issue', attributes: { change: '' }
    assert_xml_tag parent: { tag: 'issue', attributes: { change: 'added' } }, tag: 'name', content: '1042'

    get "/source/#{incident_project}/patchinfo/_meta"
    assert_response :success
    assert_xml_tag(tag: 'enable', parent: { tag: 'build' })
    assert_no_xml_tag(tag: 'publish') # noaccess

    get "/source/#{incident_project}/patchinfo?view=issues"
    assert_response :success
    assert_no_xml_tag parent: { tag: 'issue' }, tag: 'issue', attributes: { change: nil }
    assert_no_xml_tag parent: { tag: 'issue' }, tag: 'issue', attributes: { change: '' }
    assert_xml_tag parent: { tag: 'issue', attributes: { change: 'kept' } }, tag: 'name', content: '1042'

    # cleanup
    login_king
    delete '/source/home:tom:branches:kde4'
    assert_response :success
    delete '/source/home:tom:branches:OBS_Maintained:pack2'
    assert_response :success
    delete "/source/#{incident_project}"
    assert_response :success
    delete '/source/ServicePack'
    assert_response :success
  end

  def test_create_maintenance_incident
    login_king
    put '/source/Temp:Maintenance/_meta', params: '<project name="Temp:Maintenance" kind="maintenance">
                                             <title/> <description/>
                                             <person userid="maintenance_coord" role="maintainer"/>
                                           </project>'
    assert_response :success

    reset_auth
    post '/source/Temp:Maintenance', params: { cmd: 'createmaintenanceincident' }
    assert_response :unauthorized

    login_adrian
    post '/source/Temp:Maintenance', params: { cmd: 'createmaintenanceincident' }
    assert_response :forbidden
    post '/source/home:adrian', params: { cmd: 'createmaintenanceincident' }
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'incident_has_no_maintenance_project' }

    prepare_request_with_user('maintenance_coord', 'buildservice')
    # create a public maintenance incident
    post '/source/Temp:Maintenance', params: { cmd: 'createmaintenanceincident' }
    assert_response :success
    assert_xml_tag(tag: 'data', attributes: { name: 'targetproject' })
    data = REXML::Document.new(@response.body)
    incident_project = data.elements['/status/data'].text
    # incident_id=incident_project.gsub( /^Temp:Maintenance:/, "" )
    get "/source/#{incident_project}/_meta"
    assert_xml_tag(tag: 'project', attributes: { kind: 'maintenance_incident' })
    assert_xml_tag(parent: { tag: 'build' }, tag: 'disable', content: nil)
    assert_no_xml_tag(parent: { tag: 'access' }, tag: 'disable', content: nil)
    assert_xml_tag(attributes: { role: 'maintainer', userid: 'maintenance_coord' }, tag: 'person', content: nil)
    assert_xml_tag(attributes: { role: 'bugowner', userid: 'maintenance_coord' }, tag: 'person', content: nil)

    # create a maintenance incident under embargo
    post '/source/Temp:Maintenance?cmd=createmaintenanceincident&noaccess=1'
    assert_response :success
    assert_xml_tag(tag: 'data', attributes: { name: 'targetproject' })
    data = REXML::Document.new(@response.body)
    incident_project2 = data.elements['/status/data'].text
    # incident_id2=incident_project2.gsub( /^Temp:Maintenance:/, "" )
    get "/source/#{incident_project2}/_meta"
    assert_xml_tag(parent: { tag: 'build' }, tag: 'disable', content: nil)
    assert_xml_tag(parent: { tag: 'access' }, tag: 'disable', content: nil)
    assert_xml_tag(attributes: { role: 'maintainer', userid: 'maintenance_coord' }, tag: 'person', content: nil)

    # cleanup
    delete '/source/Temp:Maintenance'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'delete_error' }
    assert_match(/This maintenance project has incident projects/, @response.body)
    delete "/source/#{incident_project}"
    assert_response :success
    delete "/source/#{incident_project2}"
    assert_response :success
    delete '/source/Temp:Maintenance'
    assert_response :success
  end

  def test_manual_branch_with_extend_names
    # submit packages via mbranch
    login_tom
    post '/source/BaseDistro2.0/pack2', params: { cmd: 'branch', target_package: 'DUMMY_package', extend_package_names: '1' }
    assert_response :success
    assert_xml_tag(tag: 'data', attributes: { name: 'sourceproject' }, content: 'BaseDistro2.0:LinkedUpdateProject')
    assert_xml_tag(tag: 'data', attributes: { name: 'sourcepackage' }, content: 'pack2')
    assert_xml_tag(tag: 'data', attributes: { name: 'targetproject' }, content: 'home:tom:branches:BaseDistro2.0:LinkedUpdateProject')
    assert_xml_tag(tag: 'data', attributes: { name: 'targetpackage' }, content: 'DUMMY_package.BaseDistro2.0_LinkedUpdateProject')
    get '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
    assert_xml_tag(tag: 'entry', attributes: { name: 'DUMMY_package.BaseDistro2.0_LinkedUpdateProject' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2.linked.BaseDistro2.0_LinkedUpdateProject' })

    # check link of branched package
    get '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/DUMMY_package.BaseDistro2.0_LinkedUpdateProject/_link'
    assert_response :success
    assert_xml_tag(tag: 'link', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' })

    # check link of local linked package
    get '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2.linked.BaseDistro2.0_LinkedUpdateProject/_link'
    assert_response :success
    assert_xml_tag(tag: 'link', attributes: { project: nil })
    assert_xml_tag(tag: 'link', attributes: { package: 'DUMMY_package.BaseDistro2.0_LinkedUpdateProject' })

    # cleanup
    delete '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
  end

  def test_create_maintenance_project_and_release_packages
    # FIXME: https://github.com/rails/rails/issues/37270
    (ActiveJob::Base.descendants << ActiveJob::Base).each(&:disable_test_adapter)
    ActiveJob::Base.queue_adapter = :inline

    # Backup
    system("for i in #{Rails.root}/tmp/backend_data/projects/BaseDistro2.0.pkg/*.rev; do cp $i $i.backup; done")
    # the birthday of J.K.
    travel_to(Date.new(2010, 7, 12))

    # setup 'My:Maintenance' as a maintenance project by fetching it's meta and set a type
    login_king
    get '/source/My:Maintenance/_meta'
    assert_response :success
    maintenance_project_meta = REXML::Document.new(@response.body)
    maintenance_project_meta.elements['/project'].attributes['kind'] = 'maintenance'
    put '/source/My:Maintenance/_meta', params: maintenance_project_meta.to_s
    assert_response :success

    prepare_request_with_user('maintenance_coord', 'buildservice')
    raw_post '/source/My:Maintenance/_attribute', "<attributes><attribute namespace='OBS' name='MaintenanceIdTemplate'><value>My-%N-%Y-%C</value></attribute></attributes>"
    assert_response :success

    travel(1.second)
    # setup a maintained distro
    post '/source/BaseDistro2.0/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    travel(1.second)
    post '/source/BaseDistro2.0/_attribute', params: "<attributes><attribute namespace='OBS' name='UpdateProject' > <value>BaseDistro2.0:LinkedUpdateProject</value> </attribute> </attributes>"
    assert_response :success
    travel(1.second)
    post '/source/BaseDistro3/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success

    # validate correct :Update project setup
    get '/source/BaseDistro2.0:LinkedUpdateProject/_meta'
    assert_response :success
    assert_xml_tag(parent: { tag: 'build' }, tag: 'disable', attributes: { repository: nil, arch: nil })
    assert_xml_tag(parent: { tag: 'publish' }, tag: 'disable', attributes: { repository: nil, arch: nil })

    # create a maintenance incident
    travel(1.second)
    post '/source', params: { cmd: 'createmaintenanceincident', noaccess: 1 }
    assert_response :success
    assert_xml_tag(tag: 'data', attributes: { name: 'targetproject' })
    data = REXML::Document.new(@response.body)
    incident_project = data.elements['/status/data'].text
    incident_id = incident_project.gsub(/^My:Maintenance:/, '')
    get "/source/#{incident_project}/_meta"
    assert_response :success
    assert_xml_tag(parent: { tag: 'access' }, tag: 'disable', content: nil)
    assert_xml_tag(parent: { tag: 'build' }, tag: 'disable', content: nil)
    assert_xml_tag(parent: { tag: 'publish' }, tag: 'disable', content: nil)
    assert_xml_tag(tag: 'project', attributes: { name: incident_project, kind: 'maintenance_incident' })

    # submit packages via mbranch
    travel(1.second)
    post '/source', params: { cmd: 'branch', package: 'pack2', target_project: incident_project }
    assert_response :success

    # correct branched ?
    get "/source/#{incident_project}/pack2.BaseDistro2.0_LinkedUpdateProject/_link"
    assert_response :success
    assert_xml_tag(tag: 'link', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' })
    get "/source/#{incident_project}"
    assert_response :success
    assert_xml_tag(tag: 'directory', attributes: { count: '3' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2.BaseDistro2.0_LinkedUpdateProject' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2.linked.BaseDistro2.0_LinkedUpdateProject' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2.BaseDistro3' })
    get "/source/#{incident_project}/_meta"
    assert_response :success
    assert_xml_tag(tag: 'path', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', repository: 'BaseDistro2LinkedUpdateProject_repo' })
    assert_xml_tag(tag: 'releasetarget', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', repository: 'BaseDistro2LinkedUpdateProject_repo', trigger: 'maintenance' })
    assert_xml_tag(tag: 'releasetarget', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', trigger: 'maintenance' })
    # correct vrev ?
    get "/source/#{incident_project}/pack2.BaseDistro2.0_LinkedUpdateProject?expand=1"
    assert_response :success
    assert_xml_tag(tag: 'directory', attributes: { vrev: '4.2' })
    # validate package meta
    get "/source/#{incident_project}/pack2.BaseDistro2.0_LinkedUpdateProject/_meta"
    assert_response :success
    assert_xml_tag(parent: { tag: 'build' }, tag: 'enable', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject' })
    get "/source/#{incident_project}/pack2.linked.BaseDistro2.0_LinkedUpdateProject/_meta"
    assert_response :success
    assert_xml_tag(parent: { tag: 'build' }, tag: 'enable', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject' })
    get "/source/#{incident_project}/pack2.BaseDistro3/_meta"
    assert_response :success
    assert_xml_tag(parent: { tag: 'build' }, tag: 'enable', attributes: { repository: 'BaseDistro3' })
    # set lock disabled to check later the valid result when enabling
    post "/source/#{incident_project}?cmd=set_flag&flag=lock&status=disable"
    assert_response :success

    prepare_request_with_user('maintenance_coord', 'buildservice')

    # create some changes, including issue tracker references
    travel(1.second)
    put "/source/#{incident_project}/pack2.BaseDistro2.0_LinkedUpdateProject/dummy.changes", params: 'DUMMY bnc#1042'
    assert_response :success
    travel(1.second)
    post "/source/#{incident_project}/pack2.BaseDistro2.0_LinkedUpdateProject?unified=1&cmd=diff&filelimit=0&expand=1"
    assert_response :success
    assert_match(/DUMMY bnc#1042/, @response.body)
    get "/source/#{incident_project}/pack2.BaseDistro2.0_LinkedUpdateProject?view=issues"
    assert_response :success
    assert_xml_tag parent: { tag: 'issue', attributes: { change: 'added' } },
                   tag: 'name', content: '1042'

    # add a new package with defined link target
    travel(1.second)
    post '/source/BaseDistro2.0/packNew', params: { cmd: 'branch', target_project: incident_project, missingok: 1, extend_package_names: 1, add_repositories: 1 }
    assert_response :success
    travel(1.second)
    raw_put "/source/#{incident_project}/packNew.BaseDistro2.0_LinkedUpdateProject/packageNew.spec", File.read("#{Rails.root}/test/fixtures/backend/binary/packageNew.spec")
    assert_response :success

    # search will find this new and not yet processed incident now.
    get '/search/project', params: { match: '[repository/releasetarget/@trigger="maintenance"]' }
    assert_response :success
    assert_xml_tag parent: { tag: 'collection' }, tag: 'project', attributes: { name: incident_project }

    # Create patchinfo informations
    travel(1.second)
    post "/source/#{incident_project}?cmd=createpatchinfo&force=1"
    assert_response :success
    assert_xml_tag(tag: 'data', attributes: { name: 'targetpackage' }, content: 'patchinfo')
    assert_xml_tag(tag: 'data', attributes: { name: 'targetproject' }, content: incident_project)
    # add reader role for adrian
    get "/source/#{incident_project}/_meta"
    assert_response :success
    meta = Nokogiri::XML(@response.body, &:strict).root
    meta.add_child('<person userid="adrian" role="reader"/>')
    travel(1.second)
    put "/source/#{incident_project}/_meta", params: meta.to_xml
    assert_response :success
    get "/source/#{incident_project}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag(tag: 'patchinfo', attributes: { incident: incident_id })
    # FIXME: add another patchinfo pointing to a third place
    # add required informations about the update
    pi = Nokogiri::XML(@response.body, &:strict).root
    pi.at_xpath('.//summary').content = 'if you are bored'
    pi.at_xpath('.//description').content = 'if you are bored and really want fixes'
    pi.at_xpath('.//rating').content = 'important'
    pi.add_child('<name>oldname</name>')
    pi.add_child('<issue id="0815" tracker="bnc"/>')
    pi.add_child('<releasetarget project="BaseDistro2.0:LinkedUpdateProject"/>')
    pi.add_child('<releasetarget project="BaseDistro3"/>')
    travel(1.second)
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.to_xml
    assert_response :success
    # add broken releasetarget
    pi.add_child('<releasetarget project="home:tom"/>') # invalid target
    travel(1.second)
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.to_xml
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'releasetarget_not_found' }
    # add broken tracker
    pi.add_child('<issue id="0815" tracker="INVALID"/>') # invalid tracker
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.to_xml
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'tracker_not_found' }
    # continue
    get "/source/#{incident_project}/patchinfo/_meta"
    assert_xml_tag(parent: { tag: 'build' }, tag: 'enable', attributes: { repository: nil, arch: nil })
    assert_no_xml_tag(parent: { tag: 'publish' }, tag: 'enable', attributes: { repository: nil, arch: nil }) # not published due to access disable
    get "/source/#{incident_project}/patchinfo?view=issues"
    assert_response :success
    assert_no_xml_tag parent: { tag: 'issue' }, tag: 'issue', attributes: { change: nil }
    assert_no_xml_tag parent: { tag: 'issue' }, tag: 'issue', attributes: { change: '' }
    assert_xml_tag parent: { tag: 'issue' }, tag: 'name', content: '1042'
    assert_xml_tag parent: { tag: 'issue' }, tag: 'name', content: '0815'
    assert_xml_tag parent: { tag: 'issue' }, tag: 'tracker', content: 'bnc'

    # add another issue and update patchinfo
    travel(1.second)
    put "/source/#{incident_project}/pack2.BaseDistro2.0_LinkedUpdateProject/dummy.changes", params: 'DUMMY bnc#1042 cve-2009-0815 bnc#4201'
    assert_response :success
    get "/source/#{incident_project}/pack2.BaseDistro2.0_LinkedUpdateProject?view=issues"
    assert_response :success
    assert_xml_tag parent: { tag: 'issue', attributes: { change: 'added' } }, tag: 'name', content: '1042'
    assert_xml_tag parent: { tag: 'issue', attributes: { change: 'added' } }, tag: 'name', content: '4201'
    assert_xml_tag tag: 'kind', content: 'link'
    travel(1.second)
    post "/source/#{incident_project}/patchinfo?cmd=updatepatchinfo"
    assert_response :success
    get "/source/#{incident_project}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag(tag: 'category', content: 'security') # changed due to CVE
    assert_xml_tag(tag: 'issue', attributes: { id: '4201', tracker: 'bnc' })
    get "/source/#{incident_project}/patchinfo?view=issues"
    assert_response :success
    assert_xml_tag tag: 'kind', content: 'patchinfo'
    assert_no_xml_tag parent: { tag: 'issue' }, tag: 'issue', attributes: { change: nil }
    assert_no_xml_tag parent: { tag: 'issue' }, tag: 'issue', attributes: { change: '' }
    assert_xml_tag parent: { tag: 'issue' }, tag: 'name', content: '1042'
    assert_xml_tag parent: { tag: 'issue' }, tag: 'tracker', content: 'bnc'
    assert_xml_tag parent: { tag: 'issue' }, tag: 'name', content: '2009-0815'
    assert_xml_tag parent: { tag: 'issue' }, tag: 'tracker', content: 'cve'
    assert_xml_tag parent: { tag: 'issue' }, tag: 'name', content: '4201'
    assert_xml_tag parent: { tag: 'issue' }, tag: 'tracker', content: 'bnc'

    # test that another, new started branch is getting the source changes from this incident in flight
    post '/source/BaseDistro2.0/pack2', params: { cmd: 'branch', maintenance: 1 }
    assert_response :success
    get '/source/home:maintenance_coord:branches:BaseDistro2.0:LinkedUpdateProject/pack2.BaseDistro2.0_LinkedUpdateProject/_history'
    assert_response :success
    assert_xml_tag tag: 'revisionlist', children: { count: 2 } # branch & copy from devel
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
    get "/build/#{incident_project}/_result"
    assert_response :success
    # BaseDistro2.0_BaseDistro2LinkedUpdateProject_repo
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586', state: 'building' } },
                   tag: 'status', attributes: { package: 'pack2.BaseDistro2.0_LinkedUpdateProject', code: 'scheduled' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586' } },
                   tag: 'status', attributes: { package: 'pack2.BaseDistro3', code: 'disabled' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586' } },
                   tag: 'status', attributes: { package: 'pack2.linked.BaseDistro2.0_LinkedUpdateProject', code: 'scheduled' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586' } },
                   tag: 'status', attributes: { package: 'packNew.BaseDistro2.0_LinkedUpdateProject', code: 'scheduled' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586' } },
                   tag: 'status', attributes: { package: 'patchinfo', code: 'blocked' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'x86_64', state: 'building' } },
                   tag: 'status', attributes: { package: 'patchinfo', code: 'excluded' }
    # BaseDistro3_BaseDistro3_repo
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro3', arch: 'i586', state: 'building' } },
                   tag: 'status', attributes: { package: 'pack2.BaseDistro2.0_LinkedUpdateProject', code: 'disabled' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro3', arch: 'i586' } },
                   tag: 'status', attributes: { package: 'packNew.BaseDistro2.0_LinkedUpdateProject', code: 'disabled' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro3', arch: 'i586' } },
                   tag: 'status', attributes: { package: 'pack2.BaseDistro3', code: 'scheduled' }

    # try to create release request too early
    post '/request?cmd=create', params: "<request>
                                   <action type='maintenance_release'>
                                     <source project='#{incident_project}' />
                                   </action>
                                   <state name='new' />
                                 </request>"
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'build_not_finished' }
    # upload build result as a worker would do
    inject_build_job(incident_project, 'pack2.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'x86_64')
    inject_build_job(incident_project, 'pack2.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'i586')
    inject_build_job(incident_project, 'pack2.linked.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'x86_64')
    inject_build_job(incident_project, 'pack2.linked.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'i586')
    inject_build_job(incident_project, 'packNew.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'x86_64')
    inject_build_job(incident_project, 'packNew.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'i586')
    inject_build_job(incident_project, 'pack2.BaseDistro3', 'BaseDistro3', 'i586')
    inject_build_job(incident_project, 'pack2.BaseDistro3:package_multibuild', 'BaseDistro3', 'i586')
    # block patchinfo build
    get "/source/#{incident_project}/patchinfo/_patchinfo"
    assert_response :success
    pi = Nokogiri::XML(@response.body, &:strict).root
    pi.add_child('<stopped>The issue is not fixed for real yet</stopped>')
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.to_xml
    assert_response :success
    # collect the job results
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher
    get '/build/BaseDistro2.0:LinkedUpdateProject/_result'
    assert_response :success
    # it is unpublished, because api does not see a single published package. this still verifies that repo is not in intermediate state anymore.
    assert_xml_tag tag: 'result', attributes: { repository: 'BaseDistro2LinkedUpdateProject_repo', arch: 'i586', state: 'unpublished' }
    get "/build/#{incident_project}/_result"
    assert_response :success
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586', state: 'unpublished' } },
                   tag: 'status', attributes: { package: 'patchinfo', code: 'broken' }
    # try to create release request nevertheless
    post '/request?cmd=create&addrevision=1', params: "<request>
                                   <action type='maintenance_release'>
                                     <source project='#{incident_project}' />
                                   </action>
                                   <state name='new' />
                                 </request>"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'build_not_finished' })
    assert_match(/patchinfo patchinfo is broken/, @response.body)
    # un-block patchinfo build, but filter for an empty result
    pi.css('stopped').remove
    pi.add_child('<binary>does not exist</binary>')
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.to_xml
    assert_response :success
    # collect the job results
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher
    get "/build/#{incident_project}/_result"
    assert_response :success
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586', state: 'unpublished' } },
                   tag: 'status', attributes: { package: 'patchinfo', code: 'failed' }
    # fix it again
    pi.css('binary').remove
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.to_xml
    assert_response :success
    # collect the job results
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher
    get "/build/#{incident_project}/_result"
    assert_response :success
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject', arch: 'i586', state: 'unpublished' } },
                   tag: 'status', attributes: { package: 'patchinfo', code: 'succeeded' }
    get "/build/#{incident_project}/BaseDistro2.0_LinkedUpdateProject/i586/patchinfo/_history"
    assert_response :success

    # check updateinfo
    get "/build/#{incident_project}/BaseDistro2.0_LinkedUpdateProject/i586/patchinfo/updateinfo.xml"
    assert_response :success
    assert_xml_tag parent: { tag: 'update', attributes: { from: 'maintenance_coord', status: 'stable', type: 'security', version: '1' } }, tag: 'id', content: nil
    assert_xml_tag tag: 'reference', attributes: { href: 'https://bugzilla.novell.com/show_bug.cgi?id=1042', id: '1042', type: 'bugzilla' }
    assert_xml_tag tag: 'reference', attributes: { href: 'https://bugzilla.novell.com/show_bug.cgi?id=4201', id: '4201', type: 'bugzilla' }
    assert_xml_tag tag: 'reference', attributes: { href: 'https://www.cve.org/CVERecord?id=CVE-2009-0815', id: 'CVE-2009-0815', type: 'cve' }
    assert_no_xml_tag tag: 'reference', attributes: { href: 'https://bugzilla.novell.com/show_bug.cgi?id=' }
    assert_no_xml_tag tag: 'reference', attributes: { id: '' }
    # check updateinfo
    get "/build/#{incident_project}/BaseDistro3/i586/patchinfo/updateinfo.xml"
    assert_response :success
    assert_xml_tag parent: { tag: 'update', attributes: { from: 'maintenance_coord', status: 'stable', type: 'security', version: '1' } }, tag: 'id', content: nil

    # let's say the maintenance person wants to publish it now
    get "/source/#{incident_project}/_meta"
    assert_response :success
    maintenance_project_meta = REXML::Document.new(@response.body)
    maintenance_project_meta.elements['/project'].delete_element 'publish'
    put "/source/#{incident_project}/_meta", params: maintenance_project_meta.to_s
    assert_response :success

    # mess up patchinfo and try to create release request
    pi.add_child('<binary>does not exist</binary>')
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.to_xml
    assert_response :success
    post '/request?cmd=create&addrevision=1', params: "<request>
                                   <action type='maintenance_release'>
                                     <source project='#{incident_project}'/>
                                   </action>
                                   <state name='new'/>
                                 </request>"
    assert_response :bad_request
    assert_match(/last patchinfo patchinfo is not yet build/, @response.body)

    # revert
    pi.css('binary').remove
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.to_xml
    assert_response :success
    run_scheduler('x86_64')
    run_scheduler('i586')

    # publisher run did not happen yet
    post '/request?cmd=create&addrevision=1', params: "<request>
                                   <action type='maintenance_release'>
                                     <source project='#{incident_project}'/>
                                   </action>
                                   <state name='new'/>
                                 </request>"
    assert_response :bad_request
    assert_match(/did not finish the publish yet/, @response.body)

    # publish and release
    run_publisher
    # is it published?
    get "/published/#{incident_project}/BaseDistro3/i586/package-1.0-1.i586.rpm"
    assert_response :success
    get "/published/#{incident_project}/BaseDistro2.0_LinkedUpdateProject/x86_64/package-1.0-1.x86_64.rpm"
    assert_response :success

    # A new branch would fetch sources from us already
    post '/source', params: { cmd: 'branch', dryrun: 1, package: 'pack2' }
    assert_response :success
    assert_xml_tag(parent: { tag: 'package', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' } },
                   tag: 'devel',
                   attributes: { project: incident_project, package: 'pack2.BaseDistro2.0_LinkedUpdateProject' })
    assert_xml_tag(parent: { tag: 'package', attributes: { project: 'BaseDistro3', package: 'pack2' } },
                   tag: 'devel',
                   attributes: { project: incident_project, package: 'pack2.BaseDistro3' })

    # create release request for real
    post '/request?cmd=create&addrevision=1', params: "<request>
                                   <action type='maintenance_release'>
                                     <source project='#{incident_project}'/>
                                   </action>
                                   <state name='new'/>
                                 </request>"
    assert_response :success
    assert_no_xml_tag(tag: 'source', attributes: { package: 'pack2.0', rev: nil })
    assert_no_xml_tag(tag: 'source', attributes: { package: 'pack2.linked.0', rev: nil })
    assert_xml_tag(tag: 'source', attributes: { package: 'patchinfo', rev: nil })
    assert_no_xml_tag(tag: 'target', attributes: { project: 'BaseDistro2.0' }) # BaseDistro2 has an update project, nothing should go to GA project
    assert_no_xml_tag(tag: 'target', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' })
    assert_no_xml_tag(tag: 'target', attributes: { project: 'BaseDistro3', package: 'pack2' })
    assert_no_xml_tag(tag: 'target', attributes: { project: incident_project })
    assert_xml_tag(tag: 'target', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: "pack2.#{incident_id}" })
    assert_xml_tag(tag: 'target', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: "pack2.linked.#{incident_id}" })
    assert_xml_tag(tag: 'target', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: "packNew.#{incident_id}" })
    assert_xml_tag(tag: 'target', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: "patchinfo.#{incident_id}" })
    assert_xml_tag(tag: 'target', attributes: { project: 'BaseDistro3', package: "pack2.#{incident_id}" })
    assert_xml_tag(tag: 'target', attributes: { project: 'BaseDistro3', package: "patchinfo.#{incident_id}" })
    assert_xml_tag(tag: 'review', attributes: { by_group: 'test_group' })
    assert_xml_tag(tag: 'review', attributes: { by_user: 'fred' }) # BaseDistro2:Update pack2
    assert_xml_tag(tag: 'priority', content: 'important') # from patchinfo rating

    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']
    post "/request/#{reqid}?cmd=diff&view=xml"
    assert_response :success
    # the diffed packages
    assert_xml_tag(tag: 'old', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' })
    assert_xml_tag(tag: 'new', attributes: { project: incident_project, package: 'pack2.BaseDistro2.0_LinkedUpdateProject' })

    # check that changes get still fetched on new branches
    post '/source/BaseDistro2.0/pack2', params: { cmd: 'branch' }
    assert_response :success
    get '/source/home:maintenance_coord:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_history'
    assert_response :success
    assert_xml_tag tag: 'comment', content: /fetch updates from open incident project #{incident_project}/
    delete '/source/home:maintenance_coord:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success

    # find the request for the maintenance incident through it's parent (maintenance) project
    get '/request?view=collection&types=maintenance_release&project=My:Maintenance&subprojects=true'
    assert_response :success
    assert_xml_tag(tag: 'collection', child: { tag: 'request' })
    assert_xml_tag(tag: 'collection', attributes: { matches: '2' })

    # validate that request is diffable (not broken)
    post "/request/#{reqid}?cmd=diff"
    assert_response :success

    # source project got locked?
    get "/source/#{incident_project}/_meta"
    assert_response :success
    assert_xml_tag(parent: { tag: 'lock' }, tag: 'disable')
    assert_xml_tag(parent: { tag: 'access' }, tag: 'disable', content: nil) # but still not out there
    assert_no_xml_tag(parent: { tag: 'publish' })
    # packages are locked
    ['pack2.BaseDistro2.0_LinkedUpdateProject',
     'pack2.BaseDistro3',
     'pack2.linked.BaseDistro2.0_LinkedUpdateProject',
     'packNew.BaseDistro2.0_LinkedUpdateProject'].each do |pkg|
      get "/source/#{incident_project}/#{pkg}/_meta"
      assert_xml_tag(parent: { tag: 'lock' }, tag: 'enable')
    end
    # patchinfo not
    get "/source/#{incident_project}/patchinfo/_meta"
    assert_no_xml_tag(parent: { tag: 'lock' }, tag: 'enable')

    # incident project not visible for tom
    login_tom
    post '/request?cmd=create&addrevision=1', params: "<request>
                                   <action type='maintenance_incident'>
                                     <source project='kde4' package='kdelibs'/>
                                     <target project='#{incident_project}' releaseproject='BaseDistro2.0:LinkedUpdateProject'/>
                                   </action>
                                   <state name='new'/>
                                 </request>"
    assert_response :not_found
    # new incident request accept is blocked, but decline works
    login_adrian
    post '/request?cmd=create&addrevision=1', params: "<request>
                                   <action type='maintenance_incident'>
                                     <source project='BaseDistro3' package='pack2'/>
                                     <target project='#{incident_project}' releaseproject='BaseDistro2.0:LinkedUpdateProject'/>
                                   </action>
                                   <state name='new' />
                                 </request>"
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    nreqid = node['id']
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post "/request/#{nreqid}?cmd=changestate&newstate=accepted"
    assert_response :forbidden
    post "/request/#{nreqid}?cmd=changestate&newstate=declined"
    assert_response :success

    # unlock would fail due to open request
    post "/source/#{incident_project}", params: { cmd: 'unlock', comment: 'cleanup' }
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'open_release_request' })

    # approve review
    login_king
    post "/request/#{reqid}?cmd=changereviewstate&newstate=accepted&by_group=test_group&comment=blahfasel"
    assert_response :success
    post "/request/#{reqid}?cmd=changereviewstate&newstate=accepted&by_user=fred&comment=blahfasel" # default package reviewer
    assert_response :success
    get "/request/#{reqid}"
    assert_response :success
    assert_xml_tag(parent: { tag: 'review' }, tag: 'comment', content: 'blahfasel')
    assert_xml_tag(parent: { tag: 'state' }, tag: 'comment', content: 'All reviewers accepted request')

    get '/search/request', params: { match: 'review/@when>="2010-07-12"' }
    assert_response :success
    assert_xml_tag tag: 'request', attributes: { id: reqid }

    get '/search/request', params: { match: 'review/history/@when>="1975-07-12"' }
    assert_response :success
    assert_xml_tag tag: 'request', attributes: { id: reqid }

    SendEventEmailsJob.new.perform
    ActionMailer::Base.deliveries.clear

    # leaving a comment on an access protected project does not send mails
    assert_difference('ActionMailer::Base.deliveries.size', 0) do
      post create_request_comment_path(request_number: reqid), params: 'Release it now!'
      assert_response :success
    end

    get comments_request_path(request_number: reqid)
    assert_xml_tag tag: 'comment', attributes: { who: 'king' }, content: 'Release it now!'

    # EmbargoDate is needed for test for releasing packages
    post "/source/#{incident_project}/_attribute", params: "<attributes><attribute namespace='OBS' name='EmbargoDate'><value>INVALID_DATE_STRING</value></attribute></attributes>"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'invalid_date' })

    post "/source/#{incident_project}/_attribute", params: "<attributes><attribute namespace='OBS' name='EmbargoDate'><value>#{Time.now + 1.day}</value></attribute></attributes>"
    assert_response :success
    post "/request/#{reqid}?cmd=changestate&newstate=accepted&comment=releasing"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'under_embargo' })

    # use the special form, no time specified
    post "/source/#{incident_project}/_attribute", params: "<attributes><attribute namespace='OBS' name='EmbargoDate'><value>#{Time.now.year}-#{Time.now.month}-#{Time.now.day}</value></attribute></attributes>"
    assert_response :success
    post "/request/#{reqid}?cmd=changestate&newstate=accepted&comment=releasing"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'under_embargo' })

    # set it to yesterday, so it works below
    post "/source/#{incident_project}/_attribute",
         params: "<attributes><attribute namespace='OBS' name='EmbargoDate'><value>#{Time.now.yesterday.year}-#{Time.now.yesterday.month}-#{Time.now.yesterday.day}</value></attribute></attributes>"
    assert_response :success

    #### release packages
    # published binaries from incident still exist?
    get "/published/#{incident_project}/BaseDistro3/i586/package-1.0-1.i586.rpm"
    assert_response :success
    get "/published/#{incident_project}/BaseDistro2.0_LinkedUpdateProject/x86_64/package-1.0-1.x86_64.rpm"
    assert_response :success
    post "/request/#{reqid}?cmd=changestate&newstate=accepted&comment=releasing"
    assert_response :success
    get "/request/#{reqid}"
    assert_response :success
    assert_xml_tag(parent: { tag: 'state' }, tag: 'comment', content: 'releasing')
    run_scheduler('i586')
    run_scheduler('x86_64')
    run_publisher
    # Check that the job removed the published binaries
    get "/published/#{incident_project}/BaseDistro3/i586/package-1.0-1.i586.rpm"
    assert_response :not_found
    get "/published/#{incident_project}/BaseDistro2.0_LinkedUpdateProject/x86_64/package-1.0-1.x86_64.rpm"
    assert_response :not_found

    # vaidate freezing of source
    get "/source/#{incident_project}/pack2.BaseDistro2.0_LinkedUpdateProject/_link"
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['rev'].present?
    # but local link is not frozen
    get "/source/#{incident_project}/pack2.linked.BaseDistro2.0_LinkedUpdateProject/_link"
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['rev'].nil?

    # validate result
    get "/source/#{incident_project}/_meta"
    assert_response :success
    assert_xml_tag(parent: { tag: 'lock' }, tag: 'enable') # got locked
    assert_no_xml_tag(parent: { tag: 'access' }, tag: 'disable', content: nil) # got published, so access got enabled
    get "/source/#{incident_project}/patchinfo/_meta"
    assert_response :success
    assert_no_xml_tag(parent: { tag: 'publish' }, tag: 'enable', content: nil)
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2/_link'
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: nil, package: "pack2.#{incident_id}" }
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2?expand=1'
    assert_response :success
    assert_xml_tag(tag: 'directory', attributes: { vrev: '4.5' })
    get "/source/BaseDistro2.0:LinkedUpdateProject/pack2.#{incident_id}"
    assert_response :success
    assert_xml_tag(tag: 'directory', attributes: { vrev: '4.5' })
    get "/source/BaseDistro2.0:LinkedUpdateProject/pack2.#{incident_id}/_link"
    assert_response :not_found
    get "/source/BaseDistro2.0:LinkedUpdateProject/pack2.linked.#{incident_id}/_link"
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: nil, package: "pack2.#{incident_id}", cicount: 'copy' }
    get '/source/BaseDistro2.0:LinkedUpdateProject/patchinfo'
    assert_response :not_found
    get "/source/BaseDistro2.0:LinkedUpdateProject/patchinfo.#{incident_id}"
    assert_response :success
    get "/source/BaseDistro2.0:LinkedUpdateProject/patchinfo.#{incident_id}/_patchinfo"
    assert_response :success
    assert_xml_tag tag: 'patchinfo', attributes: { incident: incident_id }
    assert_xml_tag tag: 'packager', content: 'maintenance_coord'
    get '/build/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586'
    assert_response :success
    get "/build/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/patchinfo.#{incident_id}"
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { filename: 'updateinfo.xml' }
    get "/build/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/patchinfo.#{incident_id}/updateinfo.xml"
    assert_response :success
    # check for changed updateinfoid
    assert_xml_tag parent: { tag: 'update', attributes: { from: 'maintenance_coord', status: 'stable', type: 'security', version: '1' } }, tag: 'id', content: "My-oldname-#{Time.now.utc.year}-1"
    # check :full tree
    get '/build/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/_repository'
    assert_response :success
    assert_xml_tag parent: { tag: 'binarylist' }, tag: 'binary', attributes: { filename: 'package.rpm' }
    get '/source/BaseDistro2.0:LinkedUpdateProject/_project/_history'
    assert_response :success
    assert_xml_tag parent: { tag: 'revision' }, tag: 'comment', content: "Releasing from project My:Maintenance:#{incident_id} the update My-oldname-2010-1"
    get "/source/BaseDistro2.0:LinkedUpdateProject/patchinfo.#{incident_id}/_meta"
    assert_response :success
    # must not build in Update project
    assert_no_xml_tag(parent: { tag: 'build' }, tag: 'enable')
    # must be published in Update project
    assert_xml_tag(parent: { tag: 'publish' }, tag: 'enable', attributes: { repository: nil, arch: nil })
    get "/source/BaseDistro2.0:LinkedUpdateProject/pack2.#{incident_id}/_meta"
    assert_response :success
    # must not build in Update project
    assert_no_xml_tag(parent: { tag: 'build' }, tag: 'enable')
    # must be published only via patchinfos
    assert_no_xml_tag(parent: { tag: 'publish' }, tag: 'enable')

    # no maintenance trigger exists anymore
    get "/source/#{incident_project}/_meta"
    assert_response :success
    assert_no_xml_tag tag: 'releasetarget', attributes: { trigger: 'maintenance' }

    # search will find this incident not anymore
    get '/search/project', params: { match: '[repository/releasetarget/@trigger="maintenance"]' }
    assert_response :success
    assert_no_xml_tag parent: { tag: 'collection' }, tag: 'project', attributes: { name: incident_project }

    # check released data
    run_publisher
    get '/build/BaseDistro2.0:LinkedUpdateProject/_result'
    assert_response :success
    assert_xml_tag tag: 'result', attributes: { repository: 'BaseDistro2LinkedUpdateProject_repo', arch: 'i586', state: 'published' }
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586'
    assert_response :success
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/delete_me-1.0-1.i586.rpm'
    assert_response :success
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/package-1.0-1.i586.rpm'
    assert_response :success
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/package-1.0-1.i586.rpm?view=fileinfo'
    assert_response :success
    assert_xml_tag tag: 'name', content: 'package'
    assert_xml_tag tag: 'version', content: '1.0'
    assert_xml_tag tag: 'release', content: '1'
    assert_xml_tag tag: 'arch', content: 'i586'
    assert_xml_tag tag: 'summary', content: 'Test Package'
    assert_xml_tag tag: 'size', content: '2263'
    assert_xml_tag tag: 'description'
    assert_xml_tag tag: 'mtime'
    hashed = node = nil
    IO.popen("gunzip -cd #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/repos/BaseDistro2.0:/LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/repodata/*-updateinfo.xml.gz") do |io|
      node = REXML::Document.new(io.read)
    end
    assert_equal "My-oldname-#{Time.now.year}-1", node.elements['/updates/update/id'].first.to_s
    # verify meta data created by createrepo
    IO.popen("gunzip -cd #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/repos/BaseDistro2.0:/LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/repodata/*-primary.xml.gz") do |io|
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
    if File.exist?('/var/adm/fillup-templates') || File.exist?('/usr/share/fillup-templates/')
      # seems to be a SUSE system
      print 'createrepo seems not to create week dependencies, we want this on SUSE systems' if pac['format']['rpm:suggests'].nil?
      assert_equal 'pure_optional', pac['format']['rpm:suggests']['rpm:entry']['name']
      assert_equal 'would_be_nice', pac['format']['rpm:recommends']['rpm:entry']['name']
      assert_equal 'other_package_likes_it', pac['format']['rpm:supplements']['rpm:entry']['name']
      assert_equal 'other_package', pac['format']['rpm:enhances']['rpm:entry']['name']
    else
      puts 'WARNING: some tests are skipped on non-SUSE systems. rpmmd meta data may not be complete.'
    end
    # file lists
    IO.popen("gunzip -cd #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/repos/BaseDistro2.0:/LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/repodata/*-filelists.xml.gz") do |io|
      hashed = Xmlhash.parse(io.read)
    end
    # STDERR.puts JSON.pretty_generate(hashed)
    assert hashed['package'].pluck('file').include?('/my_packaged_file')
    # master tags
    IO.popen("cat #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/repos/BaseDistro2.0:/LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/repodata/repomd.xml") do |io|
      hashed = Xmlhash.parse(io.read)
    end
    # check repository markers
    assert_equal hashed['tags']['content'], 'update'
    assert_equal hashed['tags']['repo'].first, 'obsrepository://obstest/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo'
    found = nil
    hashed['data'].each do |d|
      found = true if d['type'] == 'updateinfo'
    end
    assert_equal found, true
    # modifyrepo tends to kill that one:
    if File.exist?('/var/adm/fillup-templates') || File.exist?('/usr/share/fillup-templates/')
      # seems to be a SUSE system
      assert_equal hashed['tags']['repo'][0], 'obsrepository://obstest/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo'
      assert hashed['tags']['repo'][1].match(/^obsbuildid:.*/) # currently a uniq number, but defined as string
      get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo?view=status'
      assert_response :success
      assert_xml_tag tag: 'status', attributes: { code: 'succeeded' }
      assert_xml_tag tag: 'buildid'
    end

    # verify that local linked packages still get branched correctly
    post '/source/BaseDistro2.0/pack2', params: { cmd: 'branch' }
    assert_response :success
    get '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
    get '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject/pack2/_link'
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: nil }
    get '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject/pack2.linked/_link'
    assert_response :success
    assert_xml_tag tag: 'link', attributes: { project: nil, package: 'pack2' }
    delete '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success

    # check ownership of packages
    get '/search/missing_owner?project=BaseDistro2.0:LinkedUpdateProject&filter=bugowner'
    assert_response :success
    # no bugowner for this
    assert_xml_tag tag: 'missing_owner', attributes: { rootproject: 'BaseDistro2.0:LinkedUpdateProject', project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2' }
    # but do not list all the incident containers here, the main package is enough
    assert_no_xml_tag tag: 'missing_owner', attributes: { package: 'pack2.0' }
    assert_no_xml_tag tag: 'missing_owner', attributes: { package: 'patchinfo.0' }

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
    assert_no_xml_tag parent: { tag: 'binarylist' }, tag: 'binary'
    # publish repo got cleaned
    run_publisher
    get '/build/BaseDistro2.0:LinkedUpdateProject/_result'
    assert_response :success
    # it is unpublished, because api does not see a single published package. this still verifies that repo is not in intermediate state anymore.
    assert_xml_tag tag: 'result', attributes: { repository: 'BaseDistro2LinkedUpdateProject_repo', arch: 'i586', state: 'unpublished' }
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586'
    assert_response :success
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/delete_me-1.0-1.i586.rpm'
    assert_response :not_found
    get '/published/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo/i586/package-1.0-1.i586.rpm'
    assert_response :not_found

    # disable lock and verify meta
    delete "/source/#{incident_project}"
    assert_response :forbidden
    post "/source/#{incident_project}", params: { cmd: 'unlock', comment: 'cleanup' }
    assert_response :success
    get "/source/#{incident_project}/_meta"
    assert_response :success
    assert_xml_tag tag: 'releasetarget', attributes: { trigger: 'maintenance' }

    # create a service pack on top of it
    put '/source/BaseDistro2.0:ServicePack1/_meta', params: '<project name="BaseDistro2.0:ServicePack1"> <title/><description/><link project="BaseDistro2.0:LinkedUpdateProject" vrevmode="extend"/></project>'
    assert_response :success
    # get current vrev
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2?view=info'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['vrev']
    vrev = node['vrev']
    vrev1 = vrev.gsub(/\..*/, '')
    vrev2 = vrev.gsub(/.*\./, '')
    # get a package
    post '/source/BaseDistro2.0:ServicePack1/pack2.linked?cmd=instantiate&makeoriginolder=1'
    assert_response :success
    get '/source/BaseDistro2.0:ServicePack1'
    assert_response :success
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2?view=info'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['vrev']
    assert_equal node['vrev'], "#{vrev1}.#{vrev2}" # untouched
    get '/source/BaseDistro2.0:ServicePack1/pack2?view=info'
    assert_response :success
    get '/source/BaseDistro2.0:ServicePack1/pack2.linked?view=info'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['vrev']
    assert_equal "#{vrev1.to_i + 1}.#{1 + 2}", node['vrev'] # X gets increased by one, Y set back and used withrevbump=2

    # new packages in Update project found, even we just project-link only to GA
    post '/source/BaseDistro2.0:LinkedUpdateProject/packNEW?cmd=copy&oproject=BaseDistro2.0&opackage=pack2'
    assert_response :success
    post '/source/BaseDistro2.0:ServicePack1/packNEW?cmd=branch'
    assert_response :success
    delete '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject/packNEW'
    assert_response :success
    # same for instantiate
    post '/source/BaseDistro2.0:ServicePack1/packNEW?cmd=instantiate'
    assert_response :success
    get '/source/BaseDistro2.0:ServicePack1/packNEW/_link'
    assert_response :success
    get '/source/BaseDistro2.0:LinkedUpdateProject/packNEW'
    assert_response :success
    assert_xml_tag tag: 'directory', attributes: { vrev: '42.1' } # X.Y scheme
    delete '/source/BaseDistro2.0:ServicePack1/packNEW'
    assert_response :success

    # create a new package instance via submit request the right way
    delete '/source/BaseDistro2.0:ServicePack1/pack2.linked'
    assert_response :success
    delete '/source/BaseDistro2.0:ServicePack1/pack2'
    assert_response :success
    post '/source/BaseDistro2.0:ServicePack1/_attribute', params: "<attributes><attribute namespace='OBS' name='MakeOriginOlder'/></attributes>"
    assert_response :success
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro2.0" package="pack2" />
                                     <target project="BaseDistro2.0:ServicePack1" package="pack2" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag tag: 'makeoriginolder', content: 'true'
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']
    # and accept it
    post "/request/#{reqid}?cmd=changestate&newstate=accepted"
    assert_response :success
    get '/source/BaseDistro2.0:ServicePack1/pack2'
    assert_response :success
    get '/source/BaseDistro2.0:ServicePack1/pack2/_link'
    assert_response :not_found # a makeoriginolder copy due to attribute
    get '/source/BaseDistro2.0:ServicePack1/pack2?view=info'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['vrev']
    assert_equal "#{vrev1.to_i + 1}.#{1 + 1 + 2}", node['vrev'] # extendvrev . reset + link + vrevbump=2
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2?view=info'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['vrev']
    assert_equal node['vrev'], "#{vrev1}.#{vrev2}" # untouched
    delete '/source/BaseDistro2.0:ServicePack1/pack2.linked'
    assert_response :success
    delete '/source/BaseDistro2.0:ServicePack1/pack2'
    assert_response :success

    # create an entirely new package via submit request the right way
    # pack2NEW is not available via project link
    post '/source/BaseDistro2.0:ServicePack1/_attribute', params: "<attributes><attribute namespace='OBS' name='MakeOriginOlder'/></attributes>"
    assert_response :success
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro2.0" package="pack2" />
                                     <target project="BaseDistro2.0:ServicePack1" package="pack2NEW" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag tag: 'makeoriginolder', content: 'true'
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']
    # and accept it
    post "/request/#{reqid}?cmd=changestate&newstate=accepted"
    assert_response :success
    get '/source/BaseDistro2.0:ServicePack1/pack2NEW'
    assert_response :success
    get '/source/BaseDistro2.0:ServicePack1/pack2NEW/_link'
    assert_response :not_found # a new copy due to MakeOriginOlder attribute.
    delete '/source/BaseDistro2.0:ServicePack1/pack2NEW'
    assert_response :success
    # must be untouched
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2?view=info'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['vrev']
    assert_equal node['vrev'], "#{vrev1}.#{vrev2}" # untouched

    # cleanup
    system("for i in #{Rails.root}/tmp/backend_data/projects/BaseDistro2.0.pkg/*.rev; do mv $i.backup $i; done")
    get "/published/#{incident_project}"
    assert_response :success
    delete '/source/home:king:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
    delete '/source/BaseDistro2.0:ServicePack1'
    assert_response :success
    delete "/source/#{incident_project}"
    assert_response :success
    delete '/source/BaseDistro3/patchinfo.0'
    assert_response :success
    delete '/source/BaseDistro3/pack2.0'
    assert_response :success
    # don't leave the broken link and just recreate it
    Backend::Connection.delete '/source/BaseDistro3/pack2?user=king'
    assert_response :success
    p = Package.find_by_project_and_name('BaseDistro3', 'pack2')
    Backend::Connection.put('/source/BaseDistro3/pack2/_meta?user=king', p.to_axml)
    raw_put '/source/BaseDistro3/pack2/pack2.spec', File.read("#{Rails.root}/test/fixtures/backend/binary/package.spec")
    assert_response :success
    inject_build_job('BaseDistro3', 'pack2.0', 'BaseDistro3_repo', 'i586', 'package_newweaktags-1.0-1.x86_64.rpm')
    inject_build_job('BaseDistro3', 'pack2.0:package_multibuild', 'BaseDistro3_repo', 'i586', 'package_newweaktags-1.0-1.x86_64.rpm')
    run_scheduler('i586')
    run_scheduler('x86_64')
    run_publisher
    # unpublished worked for sure
    get "/published/#{incident_project}"
    assert_response :not_found
  end

  def test_create_invalid_patchinfo
    login_tom
    # collons in patchinfo names are not allowed but common mistake
    post '/source/home:tom?cmd=createpatchinfo&force=1&name=home:tom'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_package_name' }
  end

  def test_create_invalid_submit_request
    login_tom
    # submit requests are not allowed against release projects
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro2.0" package="pack2" rev="0" />
                                     <target project="BaseDistro2.0:LinkedUpdateProject" package="pack2" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'submit_request_rejected' }
    assert_match(/is a maintenance release project/, @response.body)
  end

  def test_create_invalid_incident_request
    login_tom
    # without specifing target, the default target must get found via attribute
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom" />
                                     <target project="home:tom" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'no_maintenance_project' }

    # submit foreign package without releaseproject
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="My:Maintenance" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'no_maintenance_release_target' }

    # submit foreign package with wrong releaseproject
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="home:tom" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'no_maintenance_release_target' }
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="NOT_EXISTING" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }

    # double entries
    post '/request?cmd=create&addrevision=1', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="RemoteInstance:kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="BaseDistro2.0:LinkedUpdateProject" />
                                   </action>
                                   <action type="maintenance_incident">
                                     <source project="RemoteInstance:kde4" package="kdelibs" />
                                     <target project="My:Maintenance" releaseproject="BaseDistro2.0:LinkedUpdateProject" />
                                   </action>
                                   <description>To fix my &lt;bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'conflicting_actions' }
  end

  def test_create_invalid_release_request
    login_tom
    # branch a package with simple branch command (not mbranch)
    post '/source/BaseDistro/pack1', params: { cmd: :branch }
    assert_response :success
    # check source link
    get '/source/home:tom:branches:BaseDistro:Update/pack1/_link'
    assert_response :success
    # some change
    put '/source/home:tom:branches:BaseDistro:Update/pack1/file', params: 'file'
    assert_response :success
    # remove release target
    get '/source/home:tom:branches:BaseDistro:Update/_meta'
    assert_response :success
    pi = REXML::Document.new(@response.body)
    pi.elements['//repository'].delete_element 'releasetarget'
    put '/source/home:tom:branches:BaseDistro:Update/_meta', params: pi.to_s
    assert_response :success

    # Run without server side expansion
    prepare_request_with_user('maintenance_coord', 'buildservice')
    rq = '<request>
           <action type="maintenance_release">
             <source project="home:tom:branches:BaseDistro:Update" package="pack1" />
             <target project="BaseDistro:Update" package="pack1" />
           </action>
           <state name="new" />
         </request>'
    post '/request?cmd=create', params: rq
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'repository_without_releasetarget' }

    # try with server side request expansion
    rq = '<request>
           <action type="maintenance_release">
             <source project="home:tom:branches:BaseDistro:Update" />
           </action>
           <state name="new" />
         </request>'
    post '/request?cmd=create', params: rq
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'missing_patchinfo' }
    post '/request?cmd=create&ignore_build_state=1', params: rq
    assert_response :bad_request
    # assert_xml_tag :tag => 'status', :attributes => { code: 'wrong_linked_package_source' }
    assert_xml_tag tag: 'status', attributes: { code: 'missing_action' }

    # add a release target
    login_tom
    get '/source/home:tom:branches:BaseDistro:Update/_meta'
    assert_response :success
    meta = REXML::Document.new(@response.body)
    meta.elements['//repository'].add_element 'releasetarget'
    meta.elements['//releasetarget'].add_attribute(REXML::Attribute.new('project', 'BaseDistro:Update'))
    meta.elements['//releasetarget'].add_attribute(REXML::Attribute.new('repository', 'BaseDistroUpdateProject_repo'))
    put '/source/home:tom:branches:BaseDistro:Update/_meta', params: meta.to_s
    assert_response :success

    # retry
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post '/request?cmd=create', params: rq
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'missing_patchinfo' }

    # add required informations about the update
    login_tom
    post '/source/home:tom:branches:BaseDistro:Update?cmd=createpatchinfo'
    assert_response :success
    post '/source/home:tom:branches:BaseDistro:Update?cmd=createpatchinfo&name=pack1'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'package_already_exists' }
    post '/source/home:tom:branches:BaseDistro:Update?cmd=createpatchinfo'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'patchinfo_file_exists' }
    post '/source/home:tom:branches:BaseDistro:Update?cmd=createpatchinfo&force=1'
    assert_response :success

    prepare_request_with_user('maintenance_coord', 'buildservice')
    post '/request?cmd=create', params: rq
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'build_not_finished' }

    # _patchinfo still incomplete
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post '/request?cmd=create&ignore_build_state=1', params: rq
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'incomplete_patchinfo' }

    # fix patchinfo
    login_tom
    get '/source/home:tom:branches:BaseDistro:Update/patchinfo/_patchinfo'
    assert_response :success
    pi = REXML::Document.new(@response.body)
    pi.elements['//summary'].text = 'My Summary'
    put '/source/home:tom:branches:BaseDistro:Update/patchinfo/_patchinfo', params: pi.to_s
    assert_response :success

    # remove architecture
    meta.elements['//repository'].delete_element 'arch'
    put '/source/home:tom:branches:BaseDistro:Update/_meta', params: meta.to_s
    assert_response :success

    rq = '<request>
           <action type="maintenance_release">
             <source project="home:tom:branches:BaseDistro:Update" package="pack1" />
             <target project="home:tom:branches:BaseDistro:Update" package="pack1" />
           </action>
           <state name="new" />
         </request>'
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post '/request?cmd=create&ignore_build_state=1', params: rq
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'repository_without_architecture' }

    # add a wrong architecture
    login_tom
    meta.elements['//repository'].add_element 'arch'
    meta.elements['//arch'].text = 'ppc'
    put '/source/home:tom:branches:BaseDistro:Update/_meta', params: meta.to_s
    assert_response :success

    prepare_request_with_user('maintenance_coord', 'buildservice')
    post '/request?cmd=create&ignore_build_state=1', params: rq
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'architecture_order_missmatch' }

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
    meta = originmeta = Nokogiri::XML(@response.body, &:strict).root
    meta.add_child('<person userid="adrian" role="reviewer"/>')
    put '/source/BaseDistro:Update/_meta', params: meta.to_xml
    assert_response :success

    # ensure target package exists
    get '/source/BaseDistro:Update/pack2/_meta'
    assert_response :success

    login_tom
    # create project
    put '/source/home:tom:EVERGREEN/_meta', params: "<project name='home:tom:EVERGREEN'> <title/> <description/>
                                         <link project='BaseDistro:Update'/>
                                         <repository name='dummy'>
                                           <releasetarget project='BaseDistro:Update' repository='BaseDistroUpdateProject_repo' trigger='maintenance' />
                                           <arch>i586</arch>
                                          </repository>
                                        </project>"
    assert_response :success
    post '/source/home:tom:EVERGREEN/_attribute', params: "<attributes><attribute namespace='OBS' name='BranchTarget' /></attributes>"
    assert_response :success
    # create package
    put '/source/home:tom:EVERGREEN/pack/_meta', params: "<package name='pack'> <title/> <description/> </package>"
    assert_response :success

    # create release request with default reviewer
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:EVERGREEN" package="pack" />
                                     <target project="BaseDistro:Update" package="pack2" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag tag: 'review'
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']
    # revoke to unlock the source
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # create release request WITHOUT default reviewer
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:EVERGREEN" package="pack" />
                                     <target project="home:tom:EVERGREEN" package="pack2" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_no_xml_tag tag: 'review'
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']
    # revoke to unlock the source
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # but get reviewer added if defined in own project
    login_king
    put '/source/home:tom:EVERGREEN/pack2/_meta', params: "<package name='pack2'> <title/> <description/> <person userid='adrian' role='reviewer' /> </package>"
    assert_response :success
    login_tom
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:EVERGREEN" package="pack" />
                                     <target project="home:tom:EVERGREEN" package="pack2" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag tag: 'review'
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']
    # revoke to unlock the source
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # cleanup
    login_king
    put '/source/BaseDistro:Update/_meta', params: originmeta.to_xml
    assert_response :success
    delete '/source/home:tom:EVERGREEN'
    assert_response :success
  end

  def test_try_to_release_without_permissions_binary_permissions
    login_tom
    # create project without trigger
    put '/source/home:tom:test/_meta', params: "<project name='home:tom:test'> <title/> <description/>
                                         <repository name='dummy'>
                                           <releasetarget project='BaseDistro' repository='BaseDistro_repo' />
                                           <arch>i586</arch>
                                          </repository>
                                        </project>"
    assert_response :success
    # add trigger
    put '/source/home:tom:test/_meta', params: "<project name='home:tom:test'> <title/> <description/>
                                         <repository name='dummy'>
                                           <releasetarget project='BaseDistro' repository='BaseDistro_repo' trigger='maintenance' />
                                           <arch>i586</arch>
                                          </repository>
                                        </project>"
    assert_response :success
    get '/source/home:tom:test/_meta'
    assert_response :success
    assert_xml_tag(tag: 'releasetarget', attributes: { trigger: 'maintenance' })
    # create package
    put '/source/home:tom:test/pack/_meta', params: "<package name='pack'> <title/> <description/> </package>"
    assert_response :success

    # create release request
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:test" package="pack" />
                                     <target project="home:tom:test" package="pack" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']

    # fail ...
    post "/request/#{reqid}?cmd=changestate&newstate=accepted"
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'release_target_no_permission' }

    # create another request with same target must be blocked
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:test" package="pack" />
                                     <target project="home:tom:test" package="pack" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'open_release_requests' }

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
    put '/source/home:tom:test/_meta', params: "<project name='home:tom:test'> <title/> <description/> </project>"
    assert_response :success
    put '/source/home:tom:test/pack/_meta', params: "<package name='pack'> <title/> <description/> </package>"
    assert_response :success

    # create release request
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_release">
                                     <source project="home:tom:test" package="pack" />
                                     <target project="BaseDistro" package="pack" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']

    # got locked
    get '/source/home:tom:test/pack/_meta'
    assert_response :success
    assert_xml_tag(parent: { tag: 'lock' }, tag: 'enable')
    assert_no_xml_tag(parent: { tag: 'lock' }, tag: 'disable') # disable got removed

    # fail ...
    post "/request/#{reqid}?cmd=changestate&newstate=accepted"
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'post_request_no_permission' }

    # revoke request, must unlock the incident
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # disable lock and cleanup
    get '/source/home:tom:test/pack/_meta'
    assert_response :success
    assert_no_xml_tag(parent: { tag: 'lock' }, tag: 'enable')

    # cleanup
    delete '/source/home:tom:test'
    assert_response :success
  end

  def last_revision(axml)
    axml.elements('revision').last
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
    assert_xml_tag tag: 'disable', parent: { tag: 'useforbuild' }
    get '/source/BaseDistro/pack2/_meta'
    assert_response :success
    get '/source/BaseDistro/Pack3/_meta'
    assert_response :success
    assert_xml_tag tag: 'bcntsynctag', content: 'pack1'
    post '/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro'
    assert_response :forbidden
    post '/source/home:tom:CopyOfBaseDistro?cmd=copy&oproject=BaseDistro'
    assert_response :success
    get '/source/home:tom:CopyOfBaseDistro/_meta'
    assert_response :success
    assert_no_xml_tag tag: 'path'
    assert_no_xml_tag tag: 'lock'
    delete '/source/home:tom:CopyOfBaseDistro'
    assert_response :success

    # as admin
    login_king
    post '/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&nodelay=1'
    assert_response :success
    get '/source/CopyOfBaseDistro'
    assert_response :success
    assert_xml_tag(tag: 'directory', attributes: { count: '6' })
    assert_xml_tag(tag: 'entry', attributes: { name: '_product' })
    assert_xml_tag(tag: 'entry', attributes: { name: '_product:fixed-release' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'patchinfo' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack1' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'Pack3' })
    # do not crasah on second copy
    post '/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&nodelay=1'
    assert_response :success
    get '/source/CopyOfBaseDistro/_meta'
    assert_response :success
    assert_no_xml_tag tag: 'path'
    assert_no_xml_tag tag: 'lock'
    get '/source/CopyOfBaseDistro/_config'
    assert_response :success
    assert_match(/Repotype: rpm-md-legacy/, @response.body)
    get '/source/BaseDistro'
    assert_response :success
    opackages = Xmlhash.parse(@response.body)
    get '/source/CopyOfBaseDistro'
    assert_response :success
    packages = Xmlhash.parse(@response.body)
    assert_equal opackages, packages

    # compare package meta
    get '/source/CopyOfBaseDistro/pack1/_meta'
    assert_response :success
    assert_xml_tag(parent: { tag: 'useforbuild' }, tag: 'disable')
    get '/source/CopyOfBaseDistro/Pack3/_meta'
    assert_response :success
    assert_xml_tag(tag: 'bcntsynctag', content: 'pack1')
    # compare revisions
    get '/source/BaseDistro/pack2/_history'
    assert_response :success
    history = Xmlhash.parse(@response.body)
    srcmd5 = last_revision(history).value('srcmd5')
    version = last_revision(history).value('version')
    time = last_revision(history).value('time')
    vrev = last_revision(history)['vrev']
    assert_not_nil srcmd5
    get '/source/CopyOfBaseDistro/pack2/_history'
    assert_response :success
    copyhistory = Xmlhash.parse(@response.body)
    copysrcmd5 = last_revision(copyhistory).value('srcmd5')
    copyversion = last_revision(copyhistory).value('version')
    copytime = last_revision(copyhistory).value('time')
    # copyrev = last_revision(copyhistory).rev
    copyvrev = last_revision(copyhistory)['vrev']
    assert_equal srcmd5, copysrcmd5
    assert_equal vrev.to_i, copyvrev.to_i - 1 # the copy gets always an additional commit
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
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'project_copy_no_permission' }

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
    assert_xml_tag tag: 'status', attributes: { package: 'pack2', code: 'succeeded' }

    sleep(1) # to ensure that the timestamp becomes newer
    post '/source/CopyOfBaseDistro3?cmd=copy&oproject=BaseDistro3&withhistory=1&withbinaries=1&nodelay=1'
    assert_response :success
    get '/source/CopyOfBaseDistro3/_meta'
    assert_response :success
    get '/source/BaseDistro3'
    assert_response :success
    opackages = Xmlhash.parse(@response.body)
    get '/source/CopyOfBaseDistro3'
    assert_response :success
    packages = Xmlhash.parse(@response.body)
    assert_equal opackages.to_s, packages.to_s

    # compare revisions
    get '/source/BaseDistro3/pack2/_history'
    assert_response :success
    history = Xmlhash.parse(@response.body)
    srcmd5 = last_revision(history).value(:srcmd5)
    version = last_revision(history).value(:version)
    time = last_revision(history).value(:time)
    vrev = last_revision(history)['vrev']
    assert_not_nil srcmd5
    get '/source/CopyOfBaseDistro3/pack2/_history'
    assert_response :success
    copyhistory = Xmlhash.parse(@response.body)
    copysrcmd5 = last_revision(copyhistory).value(:srcmd5)
    copyversion = last_revision(copyhistory).value(:version)
    copytime = last_revision(copyhistory).value(:time)
    # copyrev = last_revision(copyhistory).rev
    copyvrev = last_revision(copyhistory)['vrev']
    assert_equal srcmd5, copysrcmd5
    assert_equal vrev.to_i + 1, copyvrev.to_i # the copy gets always a higher vrev
    assert_equal version, copyversion
    assert_not_equal time, copytime # the timestamp got not copied
    assert_equal last_revision(copyhistory).value(:user), 'king'

    # compare binaries
    run_scheduler('i586')
    get '/build/BaseDistro3/BaseDistro3_repo/i586/pack2'
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-1.i586.rpm' }
    orig = @response.body
    get '/build/CopyOfBaseDistro3/BaseDistro3_repo/i586/pack2'
    assert_response :success
    assert_equal orig, @response.body

    # verify scheduler state
    get '/build/BaseDistro3/_result'
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { package: 'pack2', code: 'succeeded' }
    get '/build/CopyOfBaseDistro3/_result'
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { package: 'pack2', code: 'succeeded' }

    delete '/source/CopyOfBaseDistro3'
    assert_response :success
  end

  def test_copy_project_for_release_with_history
    # Backup
    system("for i in #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/projects/BaseDistro.pkg/*.rev; do cp $i $i.backup; done")

    # store revisions before copy
    login_king
    get '/source/BaseDistro/pack2/_history'
    assert_response :success
    originhistory = Xmlhash.parse(@response.body)
    last = originhistory.elements('revision').last
    originsrcmd5 = last.value('srcmd5')
    originversion = last.value('version')
    origintime = last.value('time')
    originvrev = last.value('vrev')
    assert_not_nil originsrcmd5

    # as admin
    post '/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&withhistory=1&makeolder=1&nodelay=1'
    assert_response :success
    get '/source/CopyOfBaseDistro/_meta'
    assert_response :success
    get '/source/BaseDistro'
    assert_response :success
    opackages = Xmlhash.parse(@response.body)
    get '/source/CopyOfBaseDistro'
    assert_response :success
    packages = Xmlhash.parse(@response.body)
    assert_equal opackages.to_s, packages.to_s

    # compare revisions of source project
    get '/source/BaseDistro/pack2/_history'
    assert_response :success
    history = Xmlhash.parse(@response.body)
    srcmd5 = last_revision(history).value('srcmd5')
    version = last_revision(history).value('version')
    time = last_revision(history).value('time')
    # rev = last_revision(history).rev
    vrev = last_revision(history)['vrev']
    assert_not_nil srcmd5
    assert_equal originsrcmd5, srcmd5
    assert_equal originvrev.to_i + 2, vrev.to_i # vrev jumps two numbers
    assert_equal version, originversion
    assert_not_equal time, origintime
    assert_equal 'king', last_revision(history).value('user')

    # compare revisions of destination project
    get '/source/CopyOfBaseDistro/pack2/_history'
    assert_response :success
    copyhistory = Xmlhash.parse(@response.body)
    copysrcmd5 = last_revision(copyhistory).value('srcmd5')
    copyversion = last_revision(copyhistory).value('version')
    copytime = last_revision(copyhistory).value('time')
    # copyrev = last_revision(copyhistory).rev
    copyvrev = last_revision(copyhistory)['vrev']
    assert_equal originsrcmd5, copysrcmd5
    expectedvrev = "#{originvrev.to_i + 1}.1" # the copy gets incremented by one, but also extended to avoid that it can become
    assert_equal expectedvrev, copyvrev # newer than the origin project at any time later.
    assert_equal originversion, copyversion
    assert_not_equal origintime, copytime
    assert_equal 'king', last_revision(copyhistory).value('user')

    # cleanup
    system("for i in #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/projects/BaseDistro.pkg/*.rev; do mv $i.backup $i; done")
    delete '/source/CopyOfBaseDistro'
    assert_response :success
  end

  def test_copy_from_origin_with_modification_has_write_permission_check
    # this is changing also the source project
    login_tom
    post '/source/home:tom:CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&makeolder=1'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'cmd_execution_no_permission' }
    assert_match(/requires modification permission in origin project/, @response.body)

    # this is changing also the source project
    post '/source/home:tom:CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&makeoriginolder=1'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'cmd_execution_no_permission' }
    assert_match(/requires modification permission in origin project/, @response.body)
  end

  def test_copy_project_for_release_using_makeoriginolder
    # Backup
    system("for i in #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/projects/BaseDistro.pkg/*.rev; do cp $i $i.backup; done")

    # store revisions before copy
    login_tom
    get '/source/BaseDistro/pack2/_history'
    assert_response :success
    originhistory = Xmlhash.parse(@response.body)
    last = originhistory.elements('revision').last
    originsrcmd5 = last.value('srcmd5')
    originversion = last.value('version')
    origintime = last.value('time')
    originvrev = last.value('vrev')
    assert_not_nil originsrcmd5

    # as admin
    login_king
    post '/source/CopyOfBaseDistro?cmd=copy&oproject=BaseDistro&withhistory=1&makeoriginolder=1&nodelay=1'
    assert_response :success
    get '/source/CopyOfBaseDistro/_meta'
    assert_response :success
    get '/source/BaseDistro'
    assert_response :success
    opackages = Xmlhash.parse(@response.body)
    get '/source/CopyOfBaseDistro'
    assert_response :success
    packages = Xmlhash.parse(@response.body)
    assert_equal opackages.to_s, packages.to_s

    # compare revisions of source project
    get '/source/BaseDistro/pack2/_history'
    assert_response :success
    history = Xmlhash.parse(@response.body)
    srcmd5 = last_revision(history).value('srcmd5')
    version = last_revision(history).value('version')
    time = last_revision(history).value('time')
    # rev = last_revision(history).rev
    vrev = last_revision(history)['vrev']
    assert_not_nil srcmd5
    assert_equal originsrcmd5, srcmd5
    expectedvrev = "#{originvrev.to_i + 1}.1" # the origin gets incremented by one, but also extended to avoid that it can become
    # newer than the origin project at any time later.
    assert_equal expectedvrev, vrev.to_s
    assert_equal version, originversion
    assert_not_equal time, origintime
    assert_equal 'king', last_revision(history).value('user')

    # compare revisions of destination project
    get '/source/CopyOfBaseDistro/pack2/_history'
    assert_response :success
    copyhistory = Xmlhash.parse(@response.body)
    copysrcmd5 = last_revision(copyhistory).value('srcmd5')
    copyversion = last_revision(copyhistory).value('version')
    copytime = last_revision(copyhistory).value('time')
    # copyrev = last_revision(copyhistory).rev
    copyvrev = last_revision(copyhistory)['vrev']
    assert_equal originsrcmd5, copysrcmd5
    assert_equal (originvrev.to_i + 2).to_s, copyvrev.to_s # the copy is newer
    assert_equal originversion, copyversion
    assert_not_equal origintime, copytime
    assert_equal 'king', last_revision(copyhistory).value('user')

    # cleanup
    system("for i in #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/projects/BaseDistro.pkg/*.rev; do mv $i.backup $i; done")
    delete '/source/CopyOfBaseDistro'
    assert_response :success
  end
end
