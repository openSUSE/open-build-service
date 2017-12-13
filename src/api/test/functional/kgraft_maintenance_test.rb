# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength

require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'source_controller'

class MaintenanceTests < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    stub_request(:post, 'http://bugzilla.novell.com/xmlrpc.cgi').to_timeout
  end

  #   Usually updates are patches for most recent package releases.
  #   In addition kgraft updates also need to patch previously released
  #   package submissions.
  #   This is currently done by some tweaks (adding a placeholder to the
  #   channel files, ...) made by kgraft packagers.
  #   This test is meant to cover those additional steps.
  #
  # Projects:
  #
  # My:Maintenance                    - maintenance project
  # BaseDistro2.0                     - maintained project
  # home:king:branches:BaseDistro2.0  - development project
  # BaseDistro2.0:LinkedUpdateProject - link to update project
  # My:Maintenance:1                  - maintenance incident project
  # Channel                           - project to hold channel definitions
  #
  # Channels (actuall channel projects):
  #
  # BaseDistro2Channel  - channel definition for BaseDistro2 project
  # Channel/BaseDistro2 - mapping of BaseDistro2Channel into (main) channel
  # home:king:branches:BaseDistro2.0/BaseDistro2.Channel - branched channel inject placeholder
  #
  def test_kgraft_update_setup
    # setup 'My:Maintenance' as a maintenance project by fetching it's meta and set a type
    login_king
    get '/source/My:Maintenance/_meta'
    assert_response :success

    raw_post '/source/My:Maintenance/_attribute',
             "<attributes><attribute namespace='OBS' name='MaintenanceIdTemplate'><value>My-%N-%Y-%C</value></attribute></attributes>"
    assert_response :success

    # setup a maintained distro
    post '/source/BaseDistro2.0/_attribute', params: "<attributes><attribute namespace='OBS' name='Maintained' /></attributes>"
    assert_response :success
    post '/source/BaseDistro2.0/_attribute',
         params: "<attributes><attribute namespace='OBS' name='UpdateProject' > <value>BaseDistro2.0:LinkedUpdateProject</value> "\
                 "</attribute> </attributes>"
    assert_response :success

    # lock GM distro to be sure that nothing can be released to
    get '/source/BaseDistro2.0/_meta'
    assert_response :success
    assert_no_xml_tag tag: "lock" # or our fixtures have changed
    doc = REXML::Document.new(@response.body)
    doc.elements['/project'].add_element 'lock'
    doc.elements['/project/lock'].add_element 'enable'
    put '/source/BaseDistro2.0/_meta', params: doc.to_s
    assert_response :success

    # create maintenance incident for first kernel update
    post '/source', params: { cmd: 'createmaintenanceincident' }
    assert_response :success
    assert_xml_tag(tag: 'data', attributes: { name: 'targetproject' })
    data = REXML::Document.new(@response.body)
    kernel_incident_project = data.elements['/status/data'].text
    kernel_incident_id = kernel_incident_project.gsub(/^My:Maintenance:/, '')
    # submit packages via mbranch
    post '/source', params: { cmd: 'branch', package: 'pack2', target_project: kernel_incident_project, add_repositories: 1 }
    assert_response :success
    get "/source/#{kernel_incident_project}/_meta"
    assert_response :success

    # add empty kgraft container
    put "/source/BaseDistro2.0:LinkedUpdateProject/kgraft-incident-#{kernel_incident_id}/_meta",
        params: "<package name='kgraft-incident-#{kernel_incident_id}' project='BaseDistro2.0:LinkedUpdateProject'><title/><description/></package>"
    assert_response :success
    post "/source/BaseDistro2.0:LinkedUpdateProject/kgraft-incident-#{kernel_incident_id}",
         params: { cmd: 'branch', target_project: kernel_incident_project }
    assert_response :success

    # create a GA update patch
    post '/source/BaseDistro2.0/kgraft-GA', params: { cmd: 'branch', missingok: 1, extend_package_names: 1, add_repositories: 1, ignoredevel: 1 }
    assert_response :success
    raw_put "/source/home:king:branches:BaseDistro2.0/kgraft-GA.BaseDistro2.0/package.spec",
            File.open("#{Rails.root}/test/fixtures/backend/binary/package.spec").read
    assert_response :success

    # add channel
    put '/source/BaseDistro2Channel/_meta', params: '<project name="BaseDistro2Channel"><title/><description/>
                                               <build><disable/></build>
                                               <publish><enable/></publish>
                                               <repository name="channel_repo">
                                                 <arch>i586</arch>
                                                 <arch>x86_64</arch>
                                               </repository>
                                             </project>'
    assert_response :success
    put '/source/BaseDistro2Channel/_config', params: "Repotype: rpm-md-legacy\nType: spec"
    assert_response :success
    # channel def
    put '/source/Channel/_meta', params: '<project name="Channel"><title/><description/>
                                  </project>'
    assert_response :success
    put '/source/Channel/BaseDistro2/_meta', params: '<package project="Channel" name="BaseDistro2"><title/><description/></package>'
    assert_response :success
    # rubocop:disable Metrics/LineLength
    # add reference to empty kgraft container
    post '/source/Channel/BaseDistro2?cmd=importchannel', params: "<?xml version='1.0' encoding='UTF-8'?>
        <channel>
          <target project='BaseDistro2Channel' repository='channel_repo'>
            <disabled/>
          </target>
          <binaries project='BaseDistro:Update' repository='BaseDistroUpdateProject_repo' arch='i586'>
            <binary name='package' package='pack2' project='BaseDistro2.0:LinkedUpdateProject' repository='BaseDistro2LinkedUpdateProject_repo' />
          </binaries>
        </channel>"
    assert_response :success

    # NOTE: Test preparation - stop

    ### Here starts the kgraft team
    # create a update patch based on former kernel incident
    post '/source/' + kernel_incident_project + '/kgraft-incident-' + kernel_incident_id, params: { cmd: 'branch', target_project: "home:king:branches:BaseDistro2.0", maintenance: 1 }
    assert_response :success
    raw_put "/source/home:king:branches:BaseDistro2.0/kgraft-incident-0.#{kernel_incident_project.tr(':', '_')}/packageNew.spec",
            File.open("#{Rails.root}/test/fixtures/backend/binary/packageNew.spec").read
    assert_response :success

    # branch channel
    post '/source/Channel/BaseDistro2', params: { cmd: 'branch', target_project: "home:king:branches:BaseDistro2.0", extend_package_names: 1, add_repositories: 1 }
    assert_response :success
    put "/source/home:king:branches:BaseDistro2.0/BaseDistro2.Channel/_channel", params: "<?xml version='1.0' encoding='UTF-8'?>
        <channel>
          <target project='BaseDistro2Channel' repository='channel_repo'>
            <disabled/>
          </target>
          <binaries arch='i586' project='BaseDistro2.0:LinkedUpdateProject' repository='BaseDistro2LinkedUpdateProject_repo'>
            <binary name='package' package='kgraft-GA' />
          </binaries>
          <binaries arch='x86_64' project='BaseDistro2.0:LinkedUpdateProject' repository='BaseDistro2LinkedUpdateProject_repo'>
            <!-- empty kgraft container -->
            <binary name='package_newweaktags' package='kgraft-incident-0' />
          </binaries>
        </channel>"
    # rubocop:enable Metrics/LineLength
    assert_response :success

    # make the kgraft update an incident via maintenance_incident request
    post '/request?cmd=create', params: '<request>
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
    assert_xml_tag(tag: 'target', attributes: { project: 'My:Maintenance', releaseproject: 'BaseDistro2.0:LinkedUpdateProject' })
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id1 = node.value(:id)
    post "/request/#{id1}?cmd=changestate&newstate=accepted&force=1"
    assert_response :success
    get "/request/#{id1}"
    assert_response :success
    data = REXML::Document.new(@response.body)
    incident_project = data.elements['/request/action/target'].attributes.get_attribute('project').to_s
    incident_id = incident_project.gsub(/^My:Maintenance:/, '')

    # validate sources
    get "/source/" + incident_project
    assert_response :success
    assert_xml_tag tag: "directory", attributes: { count: 4 }
    assert_xml_tag tag: "entry", attributes: { name: "BaseDistro2.Channel" }
    assert_xml_tag tag: "entry", attributes: { name: "kgraft-GA.BaseDistro2.0" }
    assert_xml_tag tag: "entry", attributes: { name: "kgraft-incident-0.My_Maintenance_0" }
    assert_xml_tag tag: "entry", attributes: { name: "patchinfo" }
    get "/source/" + incident_project + "/kgraft-incident-0.My_Maintenance_0/_link"
    assert_response :success
    get "/source/" + incident_project + "/kgraft-incident-0.My_Maintenance_0/_meta"
    assert_response :success
    assert_xml_tag tag: "releasename", content: "kgraft-incident-0"

    # validate repos
    get "/source/" + incident_project + "/_meta"
    assert_response :success
    assert_xml_tag parent: { tag: "repository", attributes: { name: kernel_incident_project.tr(':', "_") } },
                   tag: "path", attributes: { project: kernel_incident_project, repository: "BaseDistro2.0_LinkedUpdateProject" }
    assert_xml_tag parent: { tag: "repository", attributes: { name: "BaseDistro2.0" } },
                   tag: "path", attributes: { project: "BaseDistro2.0", repository: "BaseDistro2_repo" }
    assert_no_xml_tag tag: "repository", attributes: { name: "BaseDistro2Channel" }

    # add disabled target repo
    post "/source/#{incident_project}?cmd=modifychannels&mode=enable_all"
    assert_response :success
    get "/source/" + incident_project + "/_meta"
    assert_response :success

    assert_xml_tag parent: { tag: "repository", attributes: { name: "BaseDistro2Channel" } },
                   tag: "path", attributes: { project: "BaseDistro2Channel", repository: "channel_repo" }
    # Verify repos point correct release target (BaseDistro2.0:LinkedUpdateProject) and have 'maintenance' trigger
    assert_xml_tag parent: { tag: "repository", attributes: { name: "My_Maintenance_0" } },
                   tag: "releasetarget",
                   attributes: {
                     project:    "BaseDistro2.0:LinkedUpdateProject",
                     repository: "BaseDistro2LinkedUpdateProject_repo",
                     trigger:    "maintenance"
                    }
    assert_xml_tag parent: { tag: "repository", attributes: { name: "My_Maintenance_0" } },
                   tag: "path", attributes: { project: "My:Maintenance:0", repository: "BaseDistro2.0_LinkedUpdateProject" }
    assert_xml_tag parent: { tag: "repository", attributes: { name: "BaseDistro2.0" } },
                   tag: "releasetarget",
                   attributes: {
                     project:    "BaseDistro2.0:LinkedUpdateProject",
                     repository: "BaseDistro2LinkedUpdateProject_repo",
                     trigger:    "maintenance"
                   }
    assert_xml_tag parent: { tag: "repository", attributes: { name: "BaseDistro2.0" } },
                   tag: "path", attributes: { project: "BaseDistro2.0", repository: "BaseDistro2_repo" }
    assert_xml_tag parent: { tag: "repository", attributes: { name: "BaseDistro2Channel" } },
                   tag: "releasetarget",
                   attributes: { project: "BaseDistro2Channel", repository: "channel_repo", trigger: "maintenance" }
    assert_xml_tag parent: { tag: "repository", attributes: { name: "BaseDistro2Channel" } },
                   tag: "path", attributes: { project: "BaseDistro2Channel", repository: "channel_repo" }

    # Create patchinfo informations
    Timecop.freeze(1)
    post "/source/#{incident_project}?cmd=createpatchinfo&force=1"
    assert_response :success
    assert_xml_tag(tag: 'data', attributes: { name: 'targetpackage' }, content: 'patchinfo')
    assert_xml_tag(tag: 'data', attributes: { name: 'targetproject' }, content: incident_project)
    get "/source/#{incident_project}/patchinfo/_patchinfo"
    assert_response :success
    assert_xml_tag(tag: 'patchinfo', attributes: { incident: incident_id })
    # add required informations about the update
    pi = ActiveXML::Node.new(@response.body)
    pi.find_first('summary').text = 'live patch'
    pi.find_first('description').text = 'live patch is always critical'
    pi.find_first('rating').text = 'critical'
    Timecop.freeze(1)
    put "/source/#{incident_project}/patchinfo/_patchinfo", params: pi.dump_xml
    assert_response :success

    ### the backend is now building the packages, injecting results
    # run scheduler once to create job file. x86_64 scheduler gets no work
    run_scheduler('x86_64')
    run_scheduler('i586')
    # check build state
    get "/build/#{incident_project}/_result"
    assert_response :success
    assert_xml_tag parent: { tag: 'result', attributes: { repository: kernel_incident_project.tr(':', '_'), arch: 'i586', code: 'building' } },
               tag: 'status', attributes: { package: "kgraft-incident-0.#{kernel_incident_project.tr(':', '_')}", code: 'scheduled' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: kernel_incident_project.tr(':', '_'), arch: 'i586', code: 'building' } },
               tag: 'status', attributes: { package: 'kgraft-GA.BaseDistro2.0', code: 'disabled' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: kernel_incident_project.tr(':', '_'), arch: 'i586', code: 'building' } },
               tag: 'status', attributes: { package: 'BaseDistro2.Channel', code: 'disabled' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: kernel_incident_project.tr(':', '_'), arch: 'i586', code: 'building' } },
               tag: 'status', attributes: { package: "patchinfo", code: 'blocked' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2Channel', arch: 'i586' } }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0', arch: 'i586', code: 'building' } },
               tag: 'status', attributes: { package: 'kgraft-GA.BaseDistro2.0', code: 'scheduled' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2.0', arch: 'i586', code: 'building' } },
               tag: 'status', attributes: { package: 'patchinfo', code: 'blocked' }

    # upload build result as a worker would do
    # Those binaries will get picked up based on previously made channel configurations
    inject_build_job(incident_project, "kgraft-incident-0.#{kernel_incident_project.tr(':', '_')}",
                     kernel_incident_project.tr(':', '_'), 'i586')
    inject_build_job(incident_project, "kgraft-incident-0.#{kernel_incident_project.tr(':', '_')}",
                     kernel_incident_project.tr(':', '_'), 'x86_64', "package_newweaktags-1.0-1.x86_64.rpm")
    inject_build_job(incident_project, "kgraft-GA.BaseDistro2.0", "BaseDistro2.0", 'i586')
    inject_build_job(incident_project, "kgraft-GA.BaseDistro2.0", "BaseDistro2.0", 'x86_64')

    # lock kernelIncident to be sure that nothing can be released to
    get '/source/' + kernel_incident_project + '/_meta'
    assert_response :success
    assert_no_xml_tag tag: "lock" # or our fixtures have changed
    doc = REXML::Document.new(@response.body)
    doc.elements['/project'].add_element 'lock'
    doc.elements['/project/lock'].add_element 'enable'
    put '/source/' + kernel_incident_project + '/_meta', params: doc.to_s
    assert_response :success

    # collect the job results
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher
    get "/build/#{incident_project}/_result"
    assert_response :success
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2Channel', arch: 'i586', state: 'published' } },
               tag: 'status', attributes: { package: 'BaseDistro2.Channel', code: 'succeeded' }
    assert_xml_tag parent: { tag: 'result', attributes: { repository: 'BaseDistro2Channel', arch: 'i586', state: 'published' } },
               tag: 'status', attributes: { package: 'patchinfo', code: 'succeeded' }
    get "/build/#{incident_project}/BaseDistro2Channel/i586/patchinfo/"
    assert_response :success

    assert_xml_tag tag: 'binary', attributes: { filename: "updateinfo.xml" }
    assert_xml_tag tag: 'binary', attributes: { filename: "package-1.0-1.src.rpm" }
    assert_xml_tag tag: 'binary', attributes: { filename: "package-1.0-1.i586.rpm" }
    assert_xml_tag tag: 'binary', attributes: { filename: "package_newweaktags-1.0-1.x86_64.rpm" }

    #
    # create release request
    post '/request?cmd=create&addrevision=1', params: '<request>
                                   <action type="maintenance_release">
                                     <source project="' + incident_project + '" />
                                   </action>
                                   <state name="new" />
                                 </request>'
    assert_response :success
    assert_no_xml_tag(tag: 'source', attributes: { package: 'BaseDistro2.Channel', rev: nil })
    assert_no_xml_tag(tag: 'source', attributes: { package: 'kgraft-GA.BaseDistro2.0', rev: nil })
    assert_xml_tag(tag: 'source', attributes: { package: 'patchinfo', rev: nil })
    # GM project may be locked, must not appear
    assert_no_xml_tag(tag: 'target', attributes: { project: 'BaseDistro2.0' })
    assert_xml_tag(parent: { tag: "action", attributes: { type: "maintenance_release" } },
                    tag: 'target', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kgraft-incident-0.1' })
    # code stream gets the sources of the packages
    assert_xml_tag(parent: { tag: "action", attributes: { type: "maintenance_release" } },
                    tag: 'source', attributes: { project: incident_project, package: 'kgraft-GA.BaseDistro2.0' })
    assert_xml_tag(parent: { tag: "action", attributes: { type: "maintenance_release" } },
                    tag: 'target', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', package: 'kgraft-GA.1' })
    # update channel file
    assert_xml_tag(parent: { tag: "action", attributes: { type: "submit" } },
                    tag: 'target', attributes: { project: 'Channel', package: 'BaseDistro2' })
    # release to channels
    assert_xml_tag(parent: { tag: "action", attributes: { type: "maintenance_release" } },
                    tag: 'source', attributes: { project: incident_project, package: 'patchinfo' })
    assert_xml_tag(parent: { tag: "action", attributes: { type: "maintenance_release" } },
                    tag: 'target', attributes: { project: 'BaseDistro2Channel', package: 'patchinfo.1' })
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    reqid = node.value(:id)

    # validate that request is diffable (not broken)
    post "/request/#{reqid}?cmd=diff"
    assert_response :success

    # link is still unfrozen and points to the correct project and package
    get "/source/#{incident_project}/kgraft-GA.BaseDistro2.0/_link"
    assert_response :success
    assert_xml_tag tag: "link", attributes: { project: "BaseDistro2.0", package: "kgraft-GA" }
    node = ActiveXML::Node.new(@response.body)
    assert_not node.has_attribute?(:rev)
    get "/source/#{incident_project}/kgraft-incident-0.My_Maintenance_0/_link"
    assert_response :success
    assert_xml_tag tag: "link", attributes: { project: "My:Maintenance:0", package: "kgraft-incident-0" }
    node = ActiveXML::Node.new(@response.body)
    assert_not node.has_attribute?(:rev)

    #### release packages
    post "/request/#{reqid}?cmd=changestate&newstate=accepted&comment=releasing"
    assert_response :success
    get "/request/#{reqid}"
    assert_response :success
    assert_xml_tag(parent: { tag: 'state' }, tag: 'comment', content: 'releasing')
    run_scheduler('x86_64')
    run_scheduler('i586')
    run_publisher

    # validate result
    get '/source/BaseDistro2Channel/patchinfo.1'
    assert_response :success

    # link target is unmodfied, so link must stay unfrozen
    get "/source/#{incident_project}/kgraft-GA.BaseDistro2.0/_link"
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert_equal false, node.has_attribute?(:rev)
    get "/source/#{incident_project}/kgraft-incident-0.My_Maintenance_0/_link"
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert_equal false, node.has_attribute?(:rev)

    # old one still branchable even though conflicting change has been released?
    post '/source', params: { cmd: 'branch', package: 'pack2', add_repositories: 1 }
    assert_response :success
    delete "/source/home:king:branches:OBS_Maintained:pack2"
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
    post "/source/BaseDistro2.0", params: { cmd: 'unlock', comment: 'revert' }
    assert_response :success
    post "/source/#{kernel_incident_project}", params: { cmd: 'unlock', comment: 'revert' }
    assert_response :success
    post "/source/#{incident_project}", params: { cmd: 'unlock', comment: 'cleanup' }
    assert_response :success
    delete "/source/#{incident_project}"
    assert_response :success
    delete "/source/BaseDistro2Channel"
    assert_response :success
    delete "/source/Channel"
    assert_response :success
    delete "/source/#{kernel_incident_project}"
    assert_response :success
  end
end
