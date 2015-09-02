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

  def test_kgraft_update_setup

    Timecop.freeze(2010, 7, 12)

    # setup 'My:Maintenance' as a maintenance project by fetching it's meta and set a type
    login_king
    get '/source/My:Maintenance/_meta'
    assert_response :success

    raw_post '/source/My:Maintenance/_attribute',
             "<attributes><attribute namespace='OBS' name='MaintenanceIdTemplate'><value>My-%N-%Y-%C</value></attribute></attributes>"
    assert_response :success

    Timecop.freeze(1)
    # setup a maintained distro
    post '/source/BaseDistro2.0/_attribute', "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    Timecop.freeze(1)
    post '/source/BaseDistro2.0/_attribute',
         "<attributes><attribute namespace='OBS' name='UpdateProject' > <value>BaseDistro2.0:LinkedUpdateProject</value> </attribute> </attributes>"
    assert_response :success

    # lock GM distro to be sure that nothing can be released to
    get '/source/BaseDistro2.0/_meta'
    assert_response :success
    assert_no_xml_tag :tag => "lock" # or our fixtures have changed
    doc = REXML::Document.new(@response.body)
    doc.elements['/project'].add_element 'lock'
    doc.elements['/project/lock'].add_element 'enable'
    put '/source/BaseDistro2.0/_meta', doc.to_s
    assert_response :success

    # create maintenance incident for first kernel update
    Timecop.freeze(1)
    post '/source', :cmd => 'createmaintenanceincident'
    assert_response :success
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetproject' } )
    data = REXML::Document.new(@response.body)
    kernelIncidentProject=data.elements['/status/data'].text
    kernelIncidentID=kernelIncidentProject.gsub( /^My:Maintenance:/, '')
    # submit packages via mbranch
    Timecop.freeze(1)
    post '/source', :cmd => 'branch', :package => 'pack2', :target_project => kernelIncidentProject, :add_repositories => 1
    assert_response :success
    get "/source/#{kernelIncidentProject}/_meta"
    assert_response :success

    # create a GA update patch
    Timecop.freeze(1)
    post '/source/BaseDistro2.0/kgraft-GA', :cmd => 'branch', :missingok => 1, :extend_package_names => 1, :add_repositories => 1, :ignoredevel => 1
    assert_response :success
    raw_put "/source/home:king:branches:BaseDistro2.0/kgraft-GA.BaseDistro2.0/package.spec",
            File.open("#{Rails.root}/test/fixtures/backend/binary/package.spec").read
    assert_response :success
    # create a update patch based on former kernel incident
    Timecop.freeze(1)
    post '/source/'+kernelIncidentProject+'/kgraft-incident-'+kernelIncidentID,
         :cmd => 'branch', :target_project => "home:king:branches:BaseDistro2.0",
         :missingok => 1, :extend_package_names => 1, :add_repositories => 1
    assert_response :success
    raw_put "/source/home:king:branches:BaseDistro2.0/kgraft-incident-0.#{kernelIncidentProject.gsub( /:/, '_')}/packageNew.spec",
            File.open("#{Rails.root}/test/fixtures/backend/binary/packageNew.spec").read
    assert_response :success

    # add channel
    put '/source/BaseDistro2Channel/_meta', '<project name="BaseDistro2Channel"><title/><description/>
                                         <build><disable/></build>
                                         <publish><enable/></publish>
                                         <repository name="channel_repo">
                                           <arch>i586</arch>
                                           <arch>x86_64</arch>
                                         </repository>
                                   </project>'
    assert_response :success
    put '/source/BaseDistro2Channel/_config', "Repotype: rpm-md-legacy\nType: spec"
    assert_response :success
    # channel def
    put '/source/Channel/_meta', '<project name="Channel"><title/><description/>
                                   </project>'
    assert_response :success
    put '/source/Channel/BaseDistro2/_meta', '<package project="Channel" name="BaseDistro2"><title/><description/></package>'
    assert_response :success
    # rubocop:disable Metrics/LineLength
    post '/source/Channel/BaseDistro2?cmd=importchannel&target_project=BaseDistro2Channel&target_repository=channel_repo', '<?xml version="1.0" encoding="UTF-8"?>
        <channel>
          <binaries project="BaseDistro:Update" repository="BaseDistroUpdateProject_repo" arch="i586">
            <binary name="package" package="pack2" project="BaseDistro2.0:LinkedUpdateProject" repository="BaseDistro2LinkedUpdateProject_repo" />
          </binaries>
        </channel>'
    assert_response :success
    post '/source/Channel/BaseDistro2', :cmd => 'branch', :target_project => "home:king:branches:BaseDistro2.0", :extend_package_names => 1, :add_repositories => 1
    assert_response :success
    raw_put "/source/home:king:branches:BaseDistro2.0/BaseDistro2.Channel/_channel", "<?xml version='1.0' encoding='UTF-8'?>
        <channel>
          <target project='BaseDistro2Channel' repository='channel_repo'/>
          <binaries arch='i586' project='BaseDistro2.0:LinkedUpdateProject' repository='BaseDistro2LinkedUpdateProject_repo'>
            <binary name='package' package='kgraft-GA' />
          </binaries>
          <binaries arch='x86_64' project='BaseDistro2.0:LinkedUpdateProject' repository='BaseDistro2LinkedUpdateProject_repo'>
            <binary name='package_newweaktags' package='kgraft-incident-0' />
          </binaries>
        </channel>"
    # rubocop:enable Metrics/LineLength
    assert_response :success

    # make the kgraft update an incident via maintenance_incident request
    post '/request?cmd=create', '<request>
                                   <action type="maintenance_incident">
                                     <source project="home:king:branches:BaseDistro2.0" />
                                     <target project="My:Maintenance" releaseproject="BaseDistro2.0:LinkedUpdateProject" />
                                     <options>
                                       <sourceupdate>cleanup</sourceupdate>
                                     </options>
                                   </action>
                                   <description>To fix my bug</description>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_xml_tag( :tag => 'target', :attributes => { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id1 = node.value(:id)
    post "/request/#{id1}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get "/request/#{id1}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    incidentProject=data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    incidentID=incidentProject.gsub( /^My:Maintenance:/, '')

    # validate sources
    get "/source/"+incidentProject
    assert_response :success
    assert_xml_tag :tag => "directory", :attributes => {count: 4}
    assert_xml_tag :tag => "entry", :attributes => {name: "BaseDistro2.Channel"}
    assert_xml_tag :tag => "entry", :attributes => {name: "kgraft-GA.BaseDistro2.0"}
    assert_xml_tag :tag => "entry", :attributes => {name: "kgraft-incident-0.My_Maintenance_0"}
    assert_xml_tag :tag => "entry", :attributes => {name: "patchinfo"}

    # validate repos
    get "/source/"+incidentProject+"/_meta"
    assert_response :success
    assert_xml_tag :parent => { :tag => "repository", :attributes => { :name => kernelIncidentProject.gsub(/:/, "_") } },
                   :tag => "path", :attributes => { :project => kernelIncidentProject, :repository => "BaseDistro2.0_LinkedUpdateProject" }
    assert_xml_tag :parent => { :tag => "repository", :attributes => { :name => "BaseDistro2.0" } },
                   :tag => "path", :attributes => { :project => "BaseDistro2.0", :repository => "BaseDistro2_repo" }
    assert_xml_tag :parent => { :tag => "repository", :attributes => { :name => "BaseDistro2Channel" } },
                   :tag => "path", :attributes => { :project => "BaseDistro2Channel", :repository => "channel_repo" }
    assert_xml_tag :parent => { :tag => "repository", :attributes => { :name => "BaseDistro2Channel" } },
                   :tag => "releasetarget",
                   :attributes => { :project => "BaseDistro2Channel", :repository => "channel_repo", :trigger => "maintenance" }


    # Create patchinfo informations
    Timecop.freeze(1)
    post "/source/#{incidentProject}?cmd=createpatchinfo&force=1"
    assert_response :success
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetpackage' }, :content => 'patchinfo')
    assert_xml_tag( :tag => 'data', :attributes => { name: 'targetproject' }, :content => incidentProject )
    get "/source/#{incidentProject}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag( :tag => 'patchinfo', :attributes => { incident: incidentID } )
    # add required informations about the update
    pi = ActiveXML::Node.new( @response.body )
    pi.find_first('summary').text = 'live patch'
    pi.find_first('description').text = 'live patch is always critical'
    pi.find_first('rating').text = 'critical'
    Timecop.freeze(1)
    raw_put "/source/#{incidentProject}/patchinfo/_patchinfo", pi.dump_xml
    assert_response :success

    ### the backend is now building the packages, injecting results
    # run scheduler once to create job file. x86_64 scheduler gets no work
    run_scheduler('x86_64')
    run_scheduler('i586')
    # check build state
    get "/build/#{incidentProject}/_result"
    assert_response :success
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: kernelIncidentProject.gsub( /:/, '_'), arch: 'i586', code: 'building' } },
               :tag => 'status', :attributes => { package: "kgraft-incident-0.#{kernelIncidentProject.gsub( /:/, '_')}", code: 'scheduled' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: kernelIncidentProject.gsub( /:/, '_'), arch: 'i586', code: 'building' } },
               :tag => 'status', :attributes => { package: 'kgraft-GA.BaseDistro2.0', code: 'disabled' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: kernelIncidentProject.gsub( /:/, '_'), arch: 'i586', code: 'building' } },
               :tag => 'status', :attributes => { package: 'BaseDistro2.Channel', code: 'disabled' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: kernelIncidentProject.gsub( /:/, '_'), arch: 'i586', code: 'building' } },
               :tag => 'status', :attributes => { package: "patchinfo", code: 'blocked' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2Channel', arch: 'i586' } }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0', arch: 'i586', code: 'building' } },
               :tag => 'status', :attributes => { package: 'kgraft-GA.BaseDistro2.0', code: 'scheduled' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2.0', arch: 'i586', code: 'building' } },
               :tag => 'status', :attributes => { package: 'patchinfo', code: 'blocked' }


    # upload build result as a worker would do
    inject_build_job( incidentProject, "kgraft-incident-0.#{kernelIncidentProject.gsub( /:/, '_')}",
                      kernelIncidentProject.gsub( /:/, '_'), 'i586')
    inject_build_job( incidentProject, "kgraft-incident-0.#{kernelIncidentProject.gsub( /:/, '_')}",
                      kernelIncidentProject.gsub( /:/, '_'), 'x86_64', "package_newweaktags-1.0-1.x86_64.rpm")
    inject_build_job( incidentProject, "kgraft-GA.BaseDistro2.0", "BaseDistro2.0", 'i586')
    inject_build_job( incidentProject, "kgraft-GA.BaseDistro2.0", "BaseDistro2.0", 'x86_64')

    # lock kernelIncident to be sure that nothing can be released to
    get '/source/'+kernelIncidentProject+'/_meta'
    assert_response :success
    assert_no_xml_tag :tag => "lock" # or our fixtures have changed
    doc = REXML::Document.new(@response.body)
    doc.elements['/project'].add_element 'lock'
    doc.elements['/project/lock'].add_element 'enable'
    put '/source/'+kernelIncidentProject+'/_meta', doc.to_s
    assert_response :success

    # collect the job results
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher
    get "/build/#{incidentProject}/_result"
    assert_response :success
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2Channel', arch: 'i586', state: 'published' } },
               :tag => 'status', :attributes => { package: 'BaseDistro2.Channel', code: 'succeeded' }
    assert_xml_tag :parent => { tag: 'result', attributes: { repository: 'BaseDistro2Channel', arch: 'i586', state: 'published' } },
               :tag => 'status', :attributes => { package: 'patchinfo', code: 'succeeded' }
    get "/build/#{incidentProject}/BaseDistro2Channel/i586/patchinfo/"
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: {filename: "updateinfo.xml"}
    assert_xml_tag tag: 'binary', attributes: {filename: "package-1.0-1.src.rpm"}
    assert_xml_tag tag: 'binary', attributes: {filename: "package-1.0-1.i586.rpm"}
    assert_xml_tag tag: 'binary', attributes: {filename: "package_newweaktags-1.0-1.x86_64.rpm"}

    #
    # create release request
    raw_post '/request?cmd=create&addrevision=1', '<request>
                                   <action type="maintenance_release">
                                     <source project="' + incidentProject + '" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_no_xml_tag( :tag => 'source', :attributes => { rev: nil } )
    # GM project may be locked, must not appear
    assert_no_xml_tag( :tag => 'target', :attributes => { project: 'BaseDistro2.0' } )
    # code stream gets the sources of the packages
    assert_xml_tag( :parent => { :tag => "action", :attributes => { :type => "maintenance_release" } },
                    :tag => 'source', :attributes => { project: incidentProject, package: 'kgraft-GA.BaseDistro2.0' } )
    assert_xml_tag( :parent => { :tag => "action", :attributes => { :type => "maintenance_release" } },
                    :tag => 'target', :attributes => { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kgraft-GA.1' } )
    # update channel file
    assert_xml_tag( :parent => { :tag => "action", :attributes => { :type => "submit" } },
                    :tag => 'target', :attributes => { project: 'Channel', package: 'BaseDistro2' } )
    # release to channels
    assert_xml_tag( :parent => { :tag => "action", :attributes => { :type => "maintenance_release" } },
                    :tag => 'source', :attributes => { project: incidentProject, package: 'patchinfo' } )
    assert_xml_tag( :parent => { :tag => "action", :attributes => { :type => "maintenance_release" } },
                    :tag => 'target', :attributes => { project: 'BaseDistro2Channel', package: 'patchinfo.1' } )
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)

    # validate that request is diffable (not broken)
    post "/request/#{reqid}?cmd=diff"
    assert_response :success

    #### release packages
    post "/request/#{reqid}?cmd=changestate&newstate=accepted&comment=releasing"
    assert_response :success
    get "/request/#{reqid}"
    assert_response :success
    assert_xml_tag( :parent => { tag: 'state' }, :tag => 'comment', :content => 'releasing')
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher

    # validate result
    get '/source/BaseDistro2Channel/patchinfo.1'
    assert_response :success

    # cleanup
    delete '/source/BaseDistro2.0:LinkedUpdateProject/kgraft-GA.1'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/kgraft-GA'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/kgraft-incident-0.1'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/kgraft-incident-0'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/patchinfo.1'
    assert_response :success
    post "/source/BaseDistro2.0", { cmd: 'unlock', comment: 'revert' }
    assert_response :success
    post "/source/#{kernelIncidentProject}", { cmd: 'unlock', comment: 'revert' }
    assert_response :success
    post "/source/#{incidentProject}", { cmd: 'unlock', comment: 'cleanup' }
    assert_response :success
    delete "/source/#{incidentProject}"
    assert_response :success
    delete "/source/#{kernelIncidentProject}"
    assert_response :success
    delete "/source/My:Maintenance"
    assert_response :success
    delete "/source/BaseDistro2Channel"
    assert_response :success
  end

end
