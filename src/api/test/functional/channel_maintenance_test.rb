# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'source_controller'

class ChannelMaintenanceTests < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    stub_request(:post, 'http://bugzilla.novell.com/xmlrpc.cgi').to_timeout
  end

  #
  # This is one large test, which is running a full maintenance update
  # This includes product channels
  # And it is doing a following up update, based on released updates
  #
  def test_large_channel_test
    # FIXME: https://github.com/rails/rails/issues/37270
    (ActiveJob::Base.descendants << ActiveJob::Base).each(&:disable_test_adapter)
    ActiveJob::Base.queue_adapter = :inline

    login_king
    put '/source/BaseDistro3/pack2/file', params: 'NOOP'
    assert_response :success
    # setup maintained attributes
    prepare_request_with_user('maintenance_coord', 'buildservice')
    # single packages
    post '/source/BaseDistro2.0/pack2/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post '/source/BaseDistro3/pack2/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success

    # search for maintained packages like osc is doing
    get '/search/package?match=%28%40name+%3D+%27pack2%27%29+and+%28project%2Fattribute%2F%40name%3D%27OBS%3AMaintained%27+or+attribute%2F%40name%3D%27OBS%3AMaintained%27%29'
    assert_response :success
    assert_xml_tag tag: 'collection', children: { count: 2 }

    # do the real mbranch for default maintained packages
    login_tom
    post '/source', params: { cmd: 'branch', package: 'pack2' }
    assert_response :success

    # validate result is done in project wide test case

    # try to create a request without a change
    post '/request?cmd=create&addrevision=1', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.BaseDistro3" />
                                     <options>
                                       <sourceupdate>cleanup</sourceupdate>
                                     </options>
                                   </action>
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'missing_action' })
    # also for entire project
    post '/request?cmd=create&addrevision=1', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2"/>
                                     <options>
                                       <sourceupdate>cleanup</sourceupdate>
                                     </options>
                                   </action>
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'missing_action' })

    # do some file changes
    put '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject/new_file', params: 'new_content_0815'
    assert_response :success
    put '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro3/file', params: 'new_content_2137'
    assert_response :success

    # create maintenance request for one package
    # without specifing target, the default target must get found via attribute
    post '/request?cmd=create&addrevision=1', params: '<request>
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
    assert_no_xml_tag(tag: 'source', attributes: { rev: nil })
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id1 = node['id']

    # validate that request is diffable (not broken)
    post "/request/#{id1}?cmd=diff&view=xml"
    assert_response :success
    # the diffed packages
    assert_xml_tag(tag: 'old', attributes: { project: 'BaseDistro3', package: 'pack2', srcmd5: 'c3f6b2ae46cbc4cfb495774733c842f0' })
    assert_xml_tag(tag: 'new', attributes: { project: 'home:tom:branches:OBS_Maintained:pack2', package: 'pack2.BaseDistro3', rev: '33fed2157de2517bc62894b3fdfd485c', srcmd5: '33fed2157de2517bc62894b3fdfd485c' })
    # the diffed files
    assert_xml_tag(tag: 'old', attributes: { name: 'file', md5: '722d122e81cbbe543bd5520bb8678c0e', size: '4' },
                   parent: { tag: 'file', attributes: { state: 'changed' } })
    assert_xml_tag(tag: 'new', attributes: { name: 'file', md5: '6c7c49c0d7106a1198fb8f1b3523c971', size: '16' },
                   parent: { tag: 'file', attributes: { state: 'changed' } })
    # the expected file transfer
    assert_xml_tag(tag: 'source', attributes: { project: 'home:tom:branches:OBS_Maintained:pack2', package: 'pack2.BaseDistro3', rev: '33fed2157de2517bc62894b3fdfd485c' })
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance', releaseproject: 'BaseDistro3' })
    # diff contains the critical lines
    assert_match(/^-NOOP/, @response.body)
    assert_match(/^\+new_content_2137/, @response.body)

    # search as used by osc sees it
    get '/search/request', params: { match: 'action/@type="maintenance_incident" and (state/@name="new" or state/@name="review") and starts-with(action/target/@project, "My:Maintenance")' }
    assert_response :success
    assert_xml_tag parent: { tag: 'collection' }, tag: 'request', attributes: { id: id1 }

    # accept request
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post "/request/#{id1}?cmd=changestate&newstate=accepted"
    assert_response :success

    get '/search/request', params: { match: 'history/@when>="2021-08-26"' }
    assert_response :success
    assert_xml_tag tag: 'request', attributes: { id: '1042' }

    get "/request/#{id1}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    incident_project = data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    assert_not_equal incident_project, 'My:Maintenance'

    # test build and publish flags
    get "/source/#{incident_project}/_meta"
    assert_xml_tag parent: { tag: 'build' }, tag: 'disable'
    assert_xml_tag parent: { tag: 'publish' }, tag: 'disable'
    assert_response :success
    get "/source/#{incident_project}/patchinfo/_meta"
    assert_response :success
    assert_xml_tag parent: { tag: 'build' }, tag: 'enable'
    assert_xml_tag parent: { tag: 'publish' }, tag: 'enable'
    assert_xml_tag parent: { tag: 'useforbuild' }, tag: 'disable'
    # add an old style patch name, only used via %N (in BaseDistro3Channel at the end of this test)
    get "/source/#{incident_project}/patchinfo/_patchinfo"
    assert_response :success
    pi = Nokogiri::XML(@response.body, &:strict).root
    pi.add_child('<name>patch_name</name>')
    pi.add_child('<message>During reboot a popup with a question will appear</message>')
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.to_xml
    assert_response :success

    # create maintenance request with invalid target
    login_tom
    post '/request?cmd=create&addrevision=1', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.BaseDistro2.0_LinkedUpdateProject" />
                                     <target project="home:tom" />
                                   </action>
                                 </request>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'no_maintenance_project' }
    # valid target..
    post '/request?cmd=create&addrevision=1', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.BaseDistro2.0_LinkedUpdateProject" />
                                     <target project="' + incident_project + '" />
                                   </action>
                                 </request>'
    assert_response :success
    assert_xml_tag(tag: 'target', attributes: { project: incident_project })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id2 = node['id']
    # ... but do not use it
    post "/request/#{id2}?cmd=changestate&newstate=revoked"
    assert_response :success

    # create maintenance request for two further packages
    # without specifing target, the default target must get found via attribute
    post '/request?cmd=create&addrevision=1', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.BaseDistro2.0_LinkedUpdateProject" />
                                   </action>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.linked.BaseDistro2.0_LinkedUpdateProject" />
                                   </action>
                                   <state name="new" />
                                   <description>To fix my other bug</description>
                                 </request>'
    assert_response :success
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id2 = node['id']
    post '/request?cmd=create&addrevision=1', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.BaseDistro2.0_LinkedUpdateProject" />
                                   </action>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.linked.BaseDistro2.0_LinkedUpdateProject" />
                                   </action>
                                   <state name="new" />
                                   <description>To fix my other bug</description>
                                 </request>'
    assert_response :success
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id3 = node['id']

    # second one for failing permission test on lock
    put '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject/dummy', params: 'dummy change'
    assert_response :success
    post '/request?cmd=create&addrevision=1', params: '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:tom:branches:OBS_Maintained:pack2" package="pack2.BaseDistro2.0_LinkedUpdateProject" />
                                   </action>
                                   <state name="new" />
                                   <description>To fix my other bug</description>
                                 </request>'
    assert_response :success
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    id4 = node['id']

    # validate that request is diffable and that the linked package is not double diffed
    post "/request/#{id2}?cmd=diff&view=xml"
    assert_response :success
    assert_match(/new_content_0815/, @response.body) # check if our changes are part of the diff
    assert_xml_tag parent: { tag: 'file', attributes: { state: 'added' } }, tag: 'new', attributes: { name: 'new_file' }

    # set incident to merge into existing one
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post "/request/#{id2}?cmd=setincident&incident=#{incident_project.gsub(/.*:/, '')}"
    assert_response :success

    get "/request/#{id2}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    maintenance_not_new_project = data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    assert_equal incident_project, maintenance_not_new_project

    # try to do it again
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post "/request/#{id2}?cmd=setincident&incident=#{incident_project.gsub(/.*:/, '')}"
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'target_not_maintenance' }

    # accept request
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post "/request/#{id2}?cmd=changestate&newstate=accepted&force=1" # ignore reviews and accept
    assert_response :success

    get "/request/#{id2}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    maintenance_not_new_project = data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    assert_equal incident_project, maintenance_not_new_project

    # validate releasename
    get '/source/' + incident_project + '/pack2.BaseDistro2.0_LinkedUpdateProject/_meta'
    assert_response :success
    assert_xml_tag tag: 'releasename', content: 'pack2'
    get '/source/' + incident_project + '/pack2.linked.BaseDistro2.0_LinkedUpdateProject/_meta'
    assert_response :success
    assert_xml_tag tag: 'releasename', content: 'pack2.linked'

    # no patchinfo was part in source project, got it created ?
    get "/source/#{incident_project}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag tag: 'packager', content: 'tom'
    assert_xml_tag tag: 'description', content: 'To fix my bug'

    #
    # Add channels
    #
    # define one
    login_king
    put '/source/BaseDistro3Channel/_meta', params: '<project name="BaseDistro3Channel" kind="maintenance_release"><title/><description/>
                                         <build><disable/></build>
                                         <publish><enable/></publish>
                                         <person userid="adrian_reader" role="reviewer" />
                                         <repository name="channel_repo">
                                           <arch>i586</arch>
                                         </repository>
                                   </project>'
    assert_response :success
    put '/source/BaseDistro3Channel/_config', params: "Repotype: rpm-md-legacy packagesubdir:rpm\nType: spec"
    assert_response :success

    raw_post '/source/BaseDistro3Channel/_attribute', "<attributes><attribute namespace='OBS' name='MaintenanceIdTemplate'><value>My-BaseDistro3Channel-%Y-%C</value></attribute></attributes>"
    assert_response :success

    put '/source/Channel/_meta', params: '<project name="Channel"><title/><description/>
                                   </project>'
    assert_response :success
    get '/source/My:Maintenance/_meta'
    assert_response :success
    meta = Nokogiri::XML(@response.body, &:strict).root
    meta.at_xpath('maintenance').add_child('<maintains project="Channel"/>')
    put '/source/My:Maintenance/_meta', params: meta.to_xml
    assert_response :success

    # create channel package
    put '/source/Channel/BaseDistro2/_meta', params: '<package project="Channel" name="BaseDistro2"><title/><description/></package>'
    assert_response :success
    # set target via parameter
    post '/source/Channel/BaseDistro2?cmd=importchannel&target_project=BaseDistro3Channel&target_repository=channel_repo', params: '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <binaries project="BaseDistro2.0:LinkedUpdateProject" repository="BaseDistro2LinkedUpdateProject_repo" arch="i586">
            <binary name="package" package="pack2.linked" project="BaseDistro2.0:LinkedUpdateProject" />
          </binaries>
        </channel>'
    assert_response :success
    # set target via xml
    put '/source/Channel/BaseDistro2.0/_meta', params: '<package project="Channel" name="BaseDistro2.0"><title/><description/></package>'
    assert_response :success
    put '/source/Channel/BaseDistro3/_meta', params: '<package project="Channel" name="BaseDistro3"><title/><description/></package>'
    assert_response :success
    post '/source/Channel/BaseDistro3?cmd=importchannel', params: '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <target project="BaseDistro3Channel" repository="channel_repo"/>
          <binaries project="BaseDistro3" repository="BaseDistro3_repo" arch="i586">
            <binary name="does_not_exist" />
          </binaries>
        </channel>'
    assert_response :success
    get '/source/Channel/BaseDistro2/_channel'
    assert_response :success
    # it found the update project
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2.linked' }
    # target repo parameter worked
    assert_xml_tag tag: 'target', attributes: { project: 'BaseDistro3Channel', repository: 'channel_repo' }
    # create channel packages and repos
    login_adrian
    post "/source/#{incident_project}?cmd=addchannels"
    assert_response :forbidden
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post "/source/#{incident_project}?cmd=addchannels"
    assert_response :success
    get "/source/#{incident_project}/BaseDistro2.Channel/_meta"
    assert_response :success

    # validate branch from projects with local channel repos
    get "/source/#{incident_project}/_meta"
    assert_response :success
    assert_xml_tag tag: 'repository', attributes: { name: 'BaseDistro3Channel' }
    post "/source/#{incident_project}/pack2.BaseDistro2.0_LinkedUpdateProject", params: { cmd: 'branch', add_repositories: 1 }
    assert_response :success
    get '/source/home:maintenance_coord:branches:My:Maintenance:0/_meta'
    assert_response :success
    # local channel got skipped:
    assert_no_xml_tag tag: 'repository', attributes: { name: 'BaseDistro3Channel' }
    post "/source/#{incident_project}/BaseDistro2.Channel", params: { cmd: 'branch', add_repositories: 1 }
    assert_response :success
    get '/source/home:maintenance_coord:branches:My:Maintenance:0/_meta'
    assert_response :success
    # added by branching the channel package container
    assert_xml_tag tag: 'repository', attributes: { name: 'BaseDistro3Channel' }
    # cleanup
    delete '/source/home:maintenance_coord:branches:My:Maintenance:0'
    assert_response :success

    # accept another request to check that addchannel is working automatically
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post "/request/#{id3}?cmd=changestate&newstate=accepted&force=1" # ignore reviews and accept
    assert_response :success
    get "/request/#{id3}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    maintenance_yet_another_project = data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    # no cleanup
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.linked.BaseDistro2.0_LinkedUpdateProject'
    assert_response :success
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject'
    assert_response :success
    get "/source/#{maintenance_yet_another_project}"
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'BaseDistro2.Channel' }
    assert_xml_tag tag: 'entry', attributes: { name: 'pack2.BaseDistro2.0_LinkedUpdateProject' }
    assert_xml_tag tag: 'entry', attributes: { name: 'pack2.linked.BaseDistro2.0_LinkedUpdateProject' }
    assert_xml_tag tag: 'entry', attributes: { name: 'patchinfo' }
    assert_xml_tag tag: 'directory', attributes: { count: '4' }
    # cleanup
    delete "/source/#{maintenance_yet_another_project}"
    assert_response :success
    # cleanup channel 2
    login_king
    delete "/source/#{incident_project}/BaseDistro2.Channel"
    assert_response :success
    delete '/source/Channel/BaseDistro2'
    assert_response :success

    put '/source/Channel/BaseDistro2.0/_channel', params: '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <target project="BaseDistro2.0:LinkedUpdateProject" repository="BaseDistro2LinkedUpdateProject_repo"><disabled/></target>
          <binaries project="BaseDistro3" repository="BaseDistro3_repo" arch="i586">
            <binary name="package" package="pack2" supportstatus="l3" />
            <binary name="does_not_exist" />
          </binaries>
        </channel>'
    assert_response :success
    put '/source/Channel/BaseDistro3/_channel', params: '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <target project="BaseDistro3Channel" repository="channel_repo" id_template="UpdateInfoTag-&#37;Y-&#37;C" requires_issue="true" />
          <binaries project="BaseDistro3" repository="BaseDistro3_repo" arch="i586">
            <binary name="package" package="pack2" supportstatus="l3" />
            <binary name="does_not_exist" />
          </binaries>
        </channel>'
    assert_response :success
    get '/source/Channel/BaseDistro3/_channel'
    assert_response :success
    assert_no_xml_tag tag: 'binary', attributes: { project: 'BaseDistro2.0', package: 'pack2.linked' }
    assert_xml_tag tag: 'binary', attributes: { project: nil, package: 'pack2', supportstatus: 'l3' }

    # create channel packages and repos
    login_adrian
    post "/source/#{incident_project}?cmd=addchannels"
    assert_response :forbidden
    prepare_request_with_user('maintenance_coord', 'buildservice')
    post "/source/#{incident_project}?cmd=addchannels&mode=skip_disabled"
    assert_response :success
    get "/source/#{incident_project}/BaseDistro2.0.Channel/_meta"
    assert_response :not_found # skipped because it just has a disabled target
    get "/source/#{incident_project}/BaseDistro3.Channel/_meta"
    assert_response :success

    post "/source/#{incident_project}/pack2.BaseDistro3?cmd=addchannels"
    assert_response :success
    post "/source/#{incident_project}?cmd=addchannels&mode=add_disabled"
    assert_response :success # now it appeared
    get "/source/#{incident_project}/BaseDistro2.0.Channel/_meta"
    assert_response :success
    get "/source/#{incident_project}/BaseDistro3.Channel/_meta"
    assert_response :success
    assert_xml_tag tag: 'enable', attributes: { repository: 'BaseDistro3Channel' },
                   parent: { tag: 'build' }
    get "/source/#{incident_project}/patchinfo/_meta" # must be global enabled for publishing
    assert_xml_tag tag: 'enable', parent: { tag: 'publish' }
    get "/source/#{incident_project}/_meta"
    assert_response :success
    assert_xml_tag tag: 'path', attributes: { project: 'BaseDistro3Channel', repository: 'channel_repo' },
                   parent: { tag: 'repository', attributes: { name: 'BaseDistro3Channel' } }
    assert_xml_tag tag: 'releasetarget', attributes: { project: 'BaseDistro3Channel', repository: 'channel_repo', trigger: 'maintenance' },
                   parent: { tag: 'repository', attributes: { name: 'BaseDistro3Channel' } }

    # create jobs, inject build results and fetch them
    run_scheduler('x86_64')
    run_scheduler('i586')
    inject_build_job(incident_project, 'pack2.BaseDistro3', 'BaseDistro3', 'i586')
    inject_build_job(incident_project, 'pack2.BaseDistro3:package_multibuild', 'BaseDistro3', 'i586')
    inject_build_job(incident_project, 'pack2.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'i586')
    inject_build_job(incident_project, 'pack2.linked.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'i586')
    inject_build_job(incident_project, 'pack2.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'x86_64')
    inject_build_job(incident_project, 'pack2.linked.BaseDistro2.0_LinkedUpdateProject', 'BaseDistro2.0_LinkedUpdateProject', 'x86_64')
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher
    get "/build/#{incident_project}/_result"
    assert_response :success
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro3', arch: 'i586', state: 'published' } }, tag: 'status', attributes: { package: 'patchinfo', code: 'succeeded' }
    # validate that patchinfo is not building in channel without an issue
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro3Channel', arch: 'i586', state: 'published' } }, tag: 'status', attributes: { package: 'patchinfo', code: 'failed' }
    # BaseDistro2 is in LTSS, repos exist but none enabled
    assert_no_xml_tag tag: 'status', attributes: { package: 'BaseDistro2.0.Channel', code: 'succeeded' }
    assert_xml_tag tag: 'status', attributes: { package: 'BaseDistro2.0.Channel', code: 'disabled' }

    # enable the patchinfo via api call
    login_king
    put '/source/BaseDistro2.0/_product/_meta', params: "<package project='BaseDistro2.0' name='_product'><title/><description/></package>"
    assert_response :success
    ['defaults-archsets.include', 'defaults-conditionals.include', 'defaults-repositories.include', 'obs.group', 'obs-release.spec', 'simple.product'].each do |file|
      raw_put "/source/BaseDistro2.0/_product/#{file}",
              File.read("#{Rails.root}/test/fixtures/backend/source/simple_product/#{file}")
      assert_response :success
    end
    prepare_request_with_user('maintenance_coord', 'buildservice')
    get "/source/#{incident_project}/BaseDistro2.0.Channel/_meta"
    old_meta = @response.body
    assert_response :success
    assert_no_xml_tag tag: 'enable', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject' }
    post "/source/#{incident_project}/BaseDistro2.0.Channel?cmd=set_flag&product=simple&flag=build&status=enable"
    assert_response :success
    get "/source/#{incident_project}/BaseDistro2.0.Channel/_meta"
    assert_response :success
    assert_xml_tag tag: 'enable', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject' }
    # revert and enable via enablechannel
    put "/source/#{incident_project}/BaseDistro2.0.Channel/_meta", params: old_meta
    assert_response :success
    post "/source/#{incident_project}/BaseDistro2.0.Channel?cmd=enablechannel"
    assert_response :success
    get "/source/#{incident_project}/BaseDistro2.0.Channel/_meta"
    assert_response :success
    assert_xml_tag tag: 'enable', attributes: { repository: 'BaseDistro2.0_LinkedUpdateProject' }

    # check repository search by product
    get "/search/repository/id?match=targetproduct/@name='simple'"
    assert_response :success
    assert_xml_tag tag: 'collection', children: { count: 2 }
    assert_xml_tag tag: 'repository', attributes: { project: 'home:tom:branches:OBS_Maintained:pack2', name: 'BaseDistro2.0_LinkedUpdateProject' }
    assert_xml_tag tag: 'repository', attributes: { project: incident_project, name: 'BaseDistro2.0_LinkedUpdateProject' }
    get "/search/repository/id?match=targetproduct[@name='simple'+and+@version='13.1']+and+@project='#{incident_project}'"
    assert_response :success
    assert_xml_tag tag: 'collection', children: { count: 1 }
    assert_xml_tag tag: 'repository', attributes: { project: incident_project, name: 'BaseDistro2.0_LinkedUpdateProject' }
    get "/search/repository/id?match=targetproduct[@name='simple'+and+@baseversion='1'+and+@patchlevel='1']"
    assert_response :success # empty, just to check for crashes

    login_king
    delete '/source/BaseDistro2.0/_product'
    assert_response :success
    prepare_request_with_user('maintenance_coord', 'buildservice')

    # no updateinfo create, so add an issue to the patchinfo
    get "/build/#{incident_project}/BaseDistro3Channel/i586/patchinfo/updateinfo.xml"
    assert_response :not_found
    get "/source/#{incident_project}/patchinfo/_patchinfo"
    assert_response :success
    pi = Nokogiri::XML(@response.body, &:strict).root
    pi.add_child('<issue id="0815" tracker="bnc"/>')
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.to_xml
    assert_response :success

    # create and check updateinfo
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher
    get "/build/#{incident_project}/BaseDistro3Channel/i586/patchinfo/updateinfo.xml"
    assert_response :success
    node = Xmlhash.parse(@response.body)
    old_release_date = node['update']['issued']['date']
    assert_equal old_release_date, old_release_date.to_i.to_s
    assert_xml_tag parent: { tag: 'update', attributes: { from: 'tom', status: 'stable', type: 'recommended', version: '1' } }, tag: 'id', content: "UpdateInfoTag-#{Time.now.utc.year}-My_Maintenance_0"

    # check published search db
    get "/search/published/binary/id?match=project='" + incident_project + "'"
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { name: 'package', project: incident_project, package: 'patchinfo',
                                                repository: 'BaseDistro3', version: '1.0', release: '1', arch: 'i586',
                                                filename: 'package-1.0-1.i586.rpm',
                                                filepath: 'My:/Maintenance:/0/BaseDistro3/i586/package-1.0-1.i586.rpm',
                                                baseproject: 'BaseDistro3', type: 'rpm' }
    assert_xml_tag tag: 'binary', attributes: { name: 'package', project: incident_project, package: 'patchinfo',
                                                repository: 'BaseDistro3Channel', version: '1.0', release: '1', arch: 'i586',
                                                filename: 'package-1.0-1.i586.rpm',
                                                filepath: 'My:/Maintenance:/0/BaseDistro3Channel/rpm/i586/package-1.0-1.i586.rpm',
                                                baseproject: 'BaseDistro3Channel', type: 'rpm' }
    get "/search/published/repoinfo/id?match=project='" + incident_project + "'"
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '3' }
    assert_xml_tag tag: 'repoinfo', attributes: { repository: 'BaseDistro3Channel', project: incident_project }
    get '/search/published/repoinfo/id?withdownloadurl=1&match=starts-with(project,"My:Maintenance:")'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '3' }
    assert_xml_tag tag: 'repoinfo', attributes: { repository: 'BaseDistro3Channel', project: incident_project }

    # create release request
    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_release">
                                     <source project="' + incident_project + '" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag tag: 'review', attributes: { by_user: 'adrian_reader', state: 'new' } # from channel
    assert_xml_tag tag: 'review', attributes: { by_user: 'fred', state: 'new' }
    assert_xml_tag tag: 'review', attributes: { by_group: 'test_group', state: 'new' }
    # no submit action
    assert_no_xml_tag tag: 'action', attributes: { type: 'submit' }
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']

    # we are not allowed to modify the target anymore, because packages are locked now
    post "/request/#{id4}?cmd=setincident&incident=#{incident_project.gsub(/.*:/, '')}"
    assert_response :success
    post "/request/#{id4}?cmd=changestate&newstate=accepted&force=1" # ignore reviews and accept
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'post_request_no_permission' }

    # revoke the release request request
    post "/request/#{reqid}?cmd=changestate&newstate=revoked"
    assert_response :success

    # and check what happens after modifing _channel file
    put '/source/My:Maintenance:0/BaseDistro3.Channel/_channel', params: '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <target project="BaseDistro3Channel" repository="channel_repo" id_template="UpdateInfoTagNew-&#37;N-&#37;Y-&#37;C" requires_issue="true" />
          <binaries project="BaseDistro3" repository="BaseDistro3_repo" arch="i586">
            <binary name="package" package="pack2" project="BaseDistro3" />
          </binaries>
        </channel>'
    assert_response :success
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher
    get "/build/#{incident_project}/_result"
    assert_response :success
    assert_xml_tag tag: 'result', attributes: { repository: 'BaseDistro3Channel', code: 'published' }
    # validate channel build results
    get "/build/#{incident_project}/BaseDistro3Channel/i586/patchinfo"
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-1.i586.rpm' }
    assert_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-1.src.rpm' }
    assert_xml_tag tag: 'binary', attributes: { filename: 'updateinfo.xml' }
    get "/published/#{incident_project}/BaseDistro3Channel/rpm/i586"
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'package-1.0-1.i586.rpm' }
    get "/published/#{incident_project}/BaseDistro3Channel/rpm/src"
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'package-1.0-1.src.rpm' }
    get "/published/#{incident_project}/BaseDistro3Channel/repodata"
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'filelists.xml.gz' }
    assert_xml_tag tag: 'entry', attributes: { name: 'other.xml.gz' }
    assert_xml_tag tag: 'entry', attributes: { name: 'primary.xml.gz' }
    assert_xml_tag tag: 'entry', attributes: { name: 'repomd.xml' }
    assert_xml_tag tag: 'entry', attributes: { name: 'updateinfo.xml.gz' }

    post '/request?cmd=create', params: '<request>
                                   <action type="maintenance_release">
                                     <source project="' + incident_project + '" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid = node['id']
    # submit action
    assert_xml_tag tag: 'target', attributes: { project: 'Channel', package: 'BaseDistro3' },
                   parent: { tag: 'action', attributes: { type: 'submit' } }
    # channel package is not released
    assert_no_xml_tag tag: 'source', attributes: { project: 'My:Maintenance:0', package: 'BaseDistro3.Channel' },
                      parent: { tag: 'action', attributes: { type: 'maintenance_release' } }
    # but it has a source change, so submit action
    assert_xml_tag tag: 'source', attributes: { project: 'My:Maintenance:0', package: 'BaseDistro3.Channel', rev: 'b8629db76e8cfb1346acf3be7501b25c' },
                   parent: { tag: 'action', attributes: { type: 'submit' } }
    # no release patchinfo into channel
    assert_no_xml_tag tag: 'target', attributes: { project: 'Channel', package: 'patchinfo.0' },
                      parent: { tag: 'action', attributes: { type: 'maintenance_release' } }
    # release of patchinfos
    assert_xml_tag tag: 'target', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'patchinfo.0' },
                   parent: { tag: 'action', attributes: { type: 'maintenance_release' } }
    assert_xml_tag tag: 'target', attributes: { project: 'BaseDistro3', package: 'patchinfo.0' },
                   parent: { tag: 'action', attributes: { type: 'maintenance_release' } }
    assert_xml_tag tag: 'target', attributes: { project: 'BaseDistro3Channel', package: 'patchinfo.0' },
                   parent: { tag: 'action', attributes: { type: 'maintenance_release' } }

    # accept release request
    login_king
    post "/request/#{reqid}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get "/request/#{reqid}"
    assert_response :success
    # check for acceptinfo
    assert_xml_tag parent: { tag: 'action', attributes: { type: 'maintenance_release' } },
                   tag: 'source', attributes: { project: 'My:Maintenance:0', package: 'pack2.BaseDistro3' }
    assert_xml_tag parent: { tag: 'action', attributes: { type: 'maintenance_release' } },
                   tag: 'target', attributes: { project: 'BaseDistro3', package: 'pack2.0' }
    assert_xml_tag parent: { tag: 'action', attributes: { type: 'maintenance_release' } },
                   tag: 'acceptinfo', attributes: { rev: '1', oproject: 'BaseDistro3', opackage: 'pack2', oxsrcmd5: 'c3f6b2ae46cbc4cfb495774733c842f0', osrcmd5: 'c3f6b2ae46cbc4cfb495774733c842f0' }

    # diffing works
    post "/request/#{reqid}?cmd=diff&view=xml"
    assert_response :success
    assert_xml_tag tag: 'old', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2.0' }
    assert_xml_tag tag: 'new', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'pack2.0' }
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher

    # validate releasename
    get '/source/BaseDistro3/pack2.0/_meta'
    assert_response :success
    assert_xml_tag tag: 'releasename', content: 'pack2'

    # collect the job results
    get "/build/#{incident_project}/_result"
    assert_response :success
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro3', arch: 'i586', state: 'published' } }, tag: 'status', attributes: { package: 'patchinfo', code: 'locked' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro3Channel', arch: 'i586', state: 'published' } }, tag: 'status', attributes: { package: 'patchinfo', code: 'locked' }

    # validate update info channel tag
    incident_id = incident_project.gsub(/.*:/, '')
    get "/build/BaseDistro3Channel/channel_repo/i586/patchinfo.#{incident_id}/updateinfo.xml"
    assert_response :success
    # check for changed updateinfoid.
    assert_xml_tag parent: { tag: 'update', attributes: { from: 'tom', status: 'stable', type: 'recommended', version: '1' } }, tag: 'id', content: "UpdateInfoTagNew-patch_name-#{Time.now.utc.year}-1"

    # repo is configured as legacy rpm-md, so we require short meta data file names
    get '/build/BaseDistro3Channel/_result'
    assert_response :success
    assert_xml_tag tag: 'result', attributes: {
      project: 'BaseDistro3Channel',
      repository: 'channel_repo',
      arch: 'i586',
      code: 'published',
      state: 'published'
    }
    get '/published/BaseDistro3Channel/channel_repo/repodata'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'filelists.xml.gz' }  # by createrepo
    assert_xml_tag tag: 'entry', attributes: { name: 'other.xml.gz' }
    assert_xml_tag tag: 'entry', attributes: { name: 'primary.xml.gz' }
    assert_xml_tag tag: 'entry', attributes: { name: 'repomd.xml' }
    assert_xml_tag tag: 'entry', attributes: { name: 'updateinfo.xml.gz' } # by modifyrepo
    IO.popen("gunzip -cd #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/repos/BaseDistro3Channel/channel_repo/repodata/updateinfo.xml.gz") do |io|
      node = Xmlhash.parse(io.read)
    end
    assert_equal "UpdateInfoTagNew-patch_name-#{Time.now.year}-1", node['update']['id']
    # our operations take way more then 1 second so far
    assert old_release_date < node['update']['issued']['date']

    # multibuild results got released as well
    get "/build/BaseDistro3/BaseDistro3_repo/i586/pack2.#{incident_id}:package_multibuild"
    assert_response :success
    get "/build/BaseDistro3Channel/channel_repo/i586/patchinfo.#{incident_id}/updateinfo.xml"
    assert_response :success
    # we should have a special rpm to test backend behaviour here

    # channel search tests
    get '/search/channel/binary?match=@name="package"'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '2' }
    assert_xml_tag parent: { tag: 'channel', attributes: { project: 'Channel', package: 'BaseDistro3' } },
                   tag: 'binary', attributes: { project: 'BaseDistro3', package: 'pack2', name: 'package' }
    assert_xml_tag parent: { tag: 'channel', attributes: { project: 'Channel', package: 'BaseDistro3' } },
                   tag: 'target', attributes: { project: 'BaseDistro3Channel', repository: 'channel_repo' }
    assert_xml_tag parent: { tag: 'target', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', repository: 'BaseDistro2LinkedUpdateProject_repo' } },
                   tag: 'updatefor', attributes: { project: 'BaseDistro', product: 'fixed', version: '1.2' }
    get '/search/channel/binary?match=@package="pack2"'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '2' }
    # channel search refers to channel package container
    get '/search/channel?match=@package="BaseDistro3"+and+binary/@package="pack2"'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '1' }
    assert_xml_tag parent: { tag: 'channel', attributes: { project: 'Channel', package: 'BaseDistro3' } },
                   tag: 'binary', attributes: { project: 'BaseDistro3', package: 'pack2', name: 'package' }
    # search by given product
    get '/search/channel/binary?match=updatefor[@project="BaseDistro"+and+@product="fixed"]'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '2' }
    get '/search/channel/binary?match=updatefor[@project="BaseDistro"+and+@product="fixed"]+and+not(target/disabled)'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '0' }

    # the old way we used to do
    get '/search/channel/binary?match=updatefor[@project="BaseDistro"+and+@product="fixed"]+and+boolean(target/disabled)'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '2' }

    # node existence check does not need a boolean()
    get '/search/channel/binary?match=updatefor[@project="BaseDistro"+and+@product="fixed"]+and+target/disabled'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '2' }

    get '/search/channel/binary?match=not(target/disabled)'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '1' }
    assert_xml_tag parent: { tag: 'channel', attributes: { project: 'Channel', package: 'BaseDistro3' } },
                   tag: 'binary', attributes: { package: 'pack2', name: 'package' }
    assert_xml_tag parent: { tag: 'channel', attributes: { project: 'Channel', package: 'BaseDistro3' } },
                   tag: 'target', attributes: { project: 'BaseDistro3Channel', repository: 'channel_repo' }

    # event handling
    UpdateNotificationEvents.new.perform
    get '/search/released/binary', params: { match: "repository[@project = 'BaseDistro3' and @name = 'BaseDistro3_repo']" }
    assert_response :success
    assert_xml_tag parent: { tag: 'binary', attributes: { name: 'package_newweaktags', version: '1.0', release: '1', arch: 'x86_64' } },
                   tag: 'publish', attributes: { package: 'pack2' }
    assert_no_xml_tag parent: { tag: 'binary', attributes: { name: 'package_newweaktags', version: '1.0', release: '1', arch: 'i586' } },
                      tag: 'obsolete'
    assert_xml_tag parent: { tag: 'binary', attributes:                      { name: 'package', version: '1.0', release: '1', arch: 'i586' } },
                   tag: 'build', attributes: { time: '2014-07-03 12:26:54 UTC' }
    assert_xml_tag parent: { tag: 'binary', attributes:                      { name: 'package', version: '1.0', release: '1', arch: 'i586' } },
                   tag: 'disturl', content: 'obs://testsuite/BaseDistro/repo/ce167c27b536e6ca39f8d951fa02a4ff-package'
    assert_xml_tag tag: 'updatefor', attributes: { project: 'BaseDistro', product: 'fixed' }

    assert_xml_tag parent: { tag: 'binary', attributes:            { name: 'package', project: 'BaseDistro3', repository: 'BaseDistro3_repo', arch: 'i586' } },
                   tag: 'operation', content: 'modified'
    assert_xml_tag parent: { tag: 'binary', attributes:            { name: 'package', project: 'BaseDistro3', repository: 'BaseDistro3_repo', arch: 'src' } },
                   tag: 'operation', content: 'added'
    assert_xml_tag parent: { tag: 'binary', attributes:            { name: 'dropped', project: 'BaseDistro3', repository: 'BaseDistro3_repo', arch: 'i586' } },
                   tag: 'operation', content: 'added'
    # entire channel content
    get '/search/released/binary', params: { match: "repository[@project = 'BaseDistro3Channel']" }
    assert_response :success
    assert_xml_tag parent: { tag: 'binary', attributes:            { name: 'package', project: 'BaseDistro3Channel', repository: 'channel_repo', arch: 'i586' } },
                   tag: 'operation', content: 'added'
    assert_xml_tag parent: { tag: 'binary', attributes:            { name: 'package', project: 'BaseDistro3Channel', repository: 'channel_repo', arch: 'i586' } },
                   tag: 'supportstatus', content: 'l3'
    assert_xml_tag parent: { tag: 'binary', attributes:            { name: 'package', project: 'BaseDistro3Channel', repository: 'channel_repo', arch: 'i586' } },
                   tag: 'updateinfo', attributes: { id: "UpdateInfoTagNew-patch_name-#{Time.now.utc.year}-1", version: '1' }
    assert_xml_tag parent: { tag: 'binary', attributes:            { name: 'package', project: 'BaseDistro3Channel', repository: 'channel_repo', arch: 'src' } },
                   tag: 'build', attributes: { time: '2014-07-03 12:26:10 UTC', binaryid: 'c360dab1651bec8b157336e6159ff83e' }

    # search via official updateinfo id tag
    get '/search/released/binary', params: { match: "updateinfo/@id = 'UpdateInfoTagNew-patch_name-#{Time.now.utc.year}-1'" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes:            { name: 'package', project: 'BaseDistro3Channel', repository: 'channel_repo', arch: 'i586' }
    assert_xml_tag tag: 'binary', attributes:            { name: 'package', project: 'BaseDistro3Channel', repository: 'channel_repo', arch: 'src' }
    assert_xml_tag tag: 'updateinfo', attributes: { id: "UpdateInfoTagNew-patch_name-#{Time.now.utc.year}-1", version: '1' }

    # drop and re-release manual release and try again
    prj = Project.find_by_name('My:Maintenance:0')
    prj.repositories.each do |repo|
      repo.release_targets.each do |rt|
        rt.trigger = 'manual'
        rt.save
      end
    end
    get '/source/BaseDistro3/pack2.0/_history'
    assert_response :success
    assert_xml_tag(tag: 'requestid')
    delete '/source/BaseDistro3/pack2'
    assert_response :success
    delete '/source/BaseDistro3/pack2.0'
    assert_response :success
    post '/source/My:Maintenance:0/pack2.BaseDistro3?cmd=release'
    assert_response :success
    get '/source/BaseDistro3/pack2.0/_history'
    assert_response :success
    assert_no_xml_tag(tag: 'requestid') # manual release entry
    get '/source/BaseDistro3/pack2'
    assert_response :not_found
    post '/source/BaseDistro3/pack2?cmd=undelete'
    assert_response :success

    #
    # A second update on top of a released one.
    # Additional channel using just a local linked package
    #
    # setup two channels for splitted product
    put '/source/Channel/BaseDistro2/_meta', params: '<package project="Channel" name="BaseDistro2"><title/><description/></package>'
    assert_response :success
    # set target via parameter
    post '/source/Channel/BaseDistro2?cmd=importchannel&target_project=BaseDistro3Channel&target_repository=channel_repo', params: '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <binaries project="BaseDistro2.0:LinkedUpdateProject" repository="BaseDistro2LinkedUpdateProject_repo" arch="i586">
            <binary name="package" package="pack2" project="BaseDistro2.0:LinkedUpdateProject" />
          </binaries>
        </channel>'
    assert_response :success
    put '/source/Channel/BaseDistro2SDK/_meta', params: '<package project="Channel" name="BaseDistro2SDK"><title/><description/></package>'
    assert_response :success
    put '/source/Channel/BaseDistro2SDK/_channel', params: '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <target project="BaseDistro3Channel" repository="channel_repo" />
          <binaries project="BaseDistro2.0:LinkedUpdateProject" repository="BaseDistro2LinkedUpdateProject_repo" arch="i586">
            <binary name="package" package="pack2.linked" supportstatus="l3" />
          </binaries>
        </channel>'
    assert_response :success
    # another change needed
    put '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject/another_file', params: 'new_content_0815_changed'
    assert_response :success
    post '/request?cmd=create&addrevision=1', params: '<request>
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
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_no_xml_tag(tag: 'source', attributes: { rev: nil })
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance' })
    node = Xmlhash.parse(@response.body)
    assert node['id']
    reqid2 = node['id']

    # accept
    post "/request/#{reqid2}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get "/request/#{reqid2}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    ontopof_update_incident_project = data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    get "/source/#{ontopof_update_incident_project}"
    assert_response :success
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2.BaseDistro2.0_LinkedUpdateProject' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2.linked.BaseDistro2.0_LinkedUpdateProject' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'BaseDistro2.Channel' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'BaseDistro2SDK.Channel' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'patchinfo' })
    assert_xml_tag(tag: 'directory', attributes: { count: '5' }) # and nothing else

    # validate cleanup
    get '/source/home:tom:branches:OBS_Maintained:pack2/pack2.BaseDistro2.0_LinkedUpdateProject'
    assert_response :not_found

    # data consistency check
    chk = ConsistencyCheckJob.new
    chk.perform # raises exception on error

    # test package initialization for projects linking to maintenance_release projects
    put '/source/TEST/_meta', params: '<project name="TEST"> <title/><description/><link project="BaseDistro2.0:LinkedUpdateProject"/></project>'
    assert_response :success
    post '/request?cmd=create', params: '<request>
                                   <action type="submit">
                                     <source project="BaseDistro3" package="pack2"/>
                                     <target project="TEST" package="pack2"/>
                                   </action>
                                   <description>Source has a devel package</description>
                                 </request>'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    id = node['id']
    assert id.present?
    post "/request/#{id}?cmd=changestate&newstate=accepted&comment=approved"
    assert_response :success
    get '/source/TEST'
    assert_response :success
    # ensure that we did not got the incident number extension, but the local linked package
    assert_xml_tag(tag: 'directory', attributes: { count: '2' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2.linked' })
    delete '/source/TEST'
    assert_response :success

    # test retracting of released updates
    # cleans up the backend and validates that DB constraints get a cleanup
    ['pack2', 'pack2.0', 'pack2.linked', 'pack2.linked.0', 'patchinfo.0'].each do |p|
      delete "/source/BaseDistro2.0:LinkedUpdateProject/#{p}"
      assert_response :success
    end
    delete '/source/BaseDistro3Channel/patchinfo.0'
    assert_response :success
    delete '/source/BaseDistro3/patchinfo.0'
    assert_response :success
    delete '/source/BaseDistro3/pack2.0'
    assert_response :success
    # reset pack2 as done in start_test_backend script
    delete '/source/BaseDistro3/pack2'
    assert_response :success
    put '/source/BaseDistro3/pack2/_meta', params: '<package project="BaseDistro3" name="pack2"><title/><description/></package>'
    assert_response :success
    raw_put '/source/BaseDistro3/pack2/package.spec', File.read("#{Rails.root}/test/fixtures/backend/binary/package.spec")
    assert_response :success

    # FIXME: re-run schedulers and check that updates got removed

    # cleanup
    login_king
    delete '/source/home:tom:branches:OBS_Maintained:pack2'
    assert_response :success
    delete '/source/BaseDistro3Channel'
    assert_response :bad_request # incident still refers to it
    delete "/source/#{incident_project}"
    assert_response :forbidden # still locked, so unlock it ...
    post "/source/#{incident_project}", params: { cmd: 'unlock', comment: 'cleanup' }
    assert_response :success
    delete "/source/#{incident_project}"
    assert_response :success
    delete "/source/#{ontopof_update_incident_project}"
    assert_response :success
    delete '/source/Channel'
    assert_response :success
    delete '/source/BaseDistro3Channel'
    assert_response :success
  end
end
