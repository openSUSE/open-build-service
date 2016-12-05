require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'source_controller'

class SourceServicesTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    wait_for_scheduler_start
    reset_auth
  end

  def test_get_servicelist
    get '/service'
    assert_response 401

    login_tom
    get '/service'
    assert_response :success
    assert_xml_tag tag: 'servicelist'

    # not using assert_xml_tag for doing a propper error message on missing
    # source service packages
    download_url = set_version = download_files = nil
    services = ActiveXML::Node.new(@response.body)
    services.each(:service) do |s|
      if s.value(:name) == 'download_url'
        download_url = 1
      end
      if s.value(:name) == 'download_files'
        download_files = 1
      end
      if s.value(:name) == 'set_version'
        set_version = 1
      end
    end
    assert_xml_tag tag: 'service', attributes: { name: 'set_version' }
    assert_xml_tag tag: 'service', attributes: { name: 'download_url' }
    assert_xml_tag tag: 'service', attributes: { name: 'download_files' }
  end

  def test_combine_project_service_list
    login_king

    put '/source/BaseDistro2.0/_project/_service',
        '<services> <service name="set_version" > <param name="version">0815</param> </service> </services>'
    assert_response :success
    put '/source/BaseDistro2.0:LinkedUpdateProject/_project/_service', '<services> <service name="download_files" /> </services>'
    assert_response :success

    login_tom
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', cmd: 'branch'
    assert_response :success
    put '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/_project/_service',
        '<services> <service name="download_url" > <param name="host">blahfasel</param> </service> </services>'
    assert_response :success

    post '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2', cmd: 'getprojectservices'
    assert_response :success
    assert_xml_tag( tag: 'service', attributes: { name: 'download_files' } )
    assert_xml_tag( parent: { tag: 'service', attributes: { name: 'download_url' } },
                    tag: 'param', attributes: { name: 'host' }, content: 'blahfasel')
    assert_xml_tag( parent: { tag: 'service', attributes: { name: 'set_version' } },
                    tag: 'param', attributes: { name: 'version' }, content: '0815')

    # cleanup
    login_king
    delete '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
    delete '/source/BaseDistro2.0/_project/_service'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/_project/_service'
    assert_response :success
  end

  def test_run_source_service
    login_tom
    put '/source/home:tom/service/_meta', "<package project='home:tom' name='service'> <title /> <description /> </package>"
    assert_response :success
    put '/source/home:tom/service/pack.spec', "# Comment \nName: pack\nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success

    put '/source/home:tom/service/_service', '<services> <service name="not_existing" /> </services>'
    assert_response :success
    assert_nil Package.find_by_project_and_name("home:tom", "service").backend_package.error
    post '/source/home:tom/service?cmd=runservice'
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response 400 # broken service
    get '/source/home:tom/service'
    assert_response :success
    assert_xml_tag tag: 'serviceinfo', attributes: { code: 'failed' }
    UpdateNotificationEvents.new.perform
    get '/source/home:tom/service?expand=1'
    assert_response 400
    assert_match(/not_existing/, @response.body) # multiple line error shows up

    put '/source/home:tom/service/_service',
        '<services> <service name="download_url" >
         <param name="host">localhost</param>
         <param name="path">/directory/subdirectory/file</param>
         </service> </services>'
    assert_response :success
    post '/source/home:tom/service?cmd=runservice'
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response :success
    get '/source/home:tom/service'
    assert_response :success
    assert_xml_tag tag: 'serviceinfo', attributes: { code: 'succeeded' }
    assert_no_xml_tag parent: { tag: 'serviceinfo' }, tag: 'error'
    get '/source/home:tom/service/_service:download_url:file?expand=1'
    assert_response :success
    post '/source/home:tom/service?cmd=servicediff', nil
    assert_match(/download_url:file/, @response.body)
    assert_response :success

    # submit to other package
    post '/request?cmd=create', '<request>
                                   <action type="submit">
                                     <source project="home:tom" package="service"/>
                                     <target project="home:tom" package="new_package"/>
                                   </action>
                                 </request>'
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value('id')

    # accept
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success

    # same result as in source package
    get '/source/home:tom/new_package'
    assert_response :success
    assert_xml_tag tag: 'serviceinfo', attributes: { code: 'succeeded' }
    assert_no_xml_tag parent: { tag: 'serviceinfo' }, tag: 'error'
    get '/source/home:tom/new_package/_service:download_url:file?expand=1'
    assert_response :success

    # branch and submit requsts
    post '/source/home:tom/service', cmd: 'branch'
    assert_response :success
    assert_nil Package.find_by_project_and_name("home:tom:branches:home:tom", "service").backend_package.error
    put '/source/home:tom:branches:home:tom/service/new_file', 'content'
    assert_response :success
    assert_nil Package.find_by_project_and_name("home:tom:branches:home:tom", "service").backend_package.error
    post '/source/home:tom:branches:home:tom/service?cmd=waitservice'
    assert_response :success
    UpdateNotificationEvents.new.perform
    assert_nil Package.find_by_project_and_name("home:tom:branches:home:tom", "service").backend_package.error
    get '/source/home:tom:branches:home:tom/service/_service:download_url:file?expand=1'
    assert_response :success
    post '/request?cmd=create', '<request>
                                   <action type="submit">
                                     <source project="home:tom:branches:home:tom" package="service"/>
                                     <target project="home:tom" package="service"/>
                                     <options>
                                       <sourceupdate>update</sourceupdate>
                                     </options>
                                   </action>
                                 </request>'
    assert_response :success
    node = ActiveXML::Node.new(@response.body)
    assert node.has_attribute?(:id)
    id = node.value('id')
    # accept
    post "/request/#{id}?cmd=changestate&newstate=accepted"
    assert_response :success
    get '/source/home:tom:branches:home:tom/service/_service:download_url:file?expand=1'
    assert_response :success
    get '/source/home:tom/service/_service:download_url:file?expand=1'
    assert_response :success

    # package copy tests
    get '/source/home:tom/service/_service:download_url:file?expand=1'
    assert_response :success
    original_file = @response.body
    post '/source/home:tom/copied_service', cmd: 'copy', noservice: '1', opackage: 'service', oproject: 'home:tom'
    assert_response :success
    get '/source/home:tom/copied_service?expand=1'
    assert_response :success
    assert_xml_tag tag: "entry", attributes: { name: "_service:download_url:file" }
    get '/source/home:tom/copied_service/_service:download_url:file?expand=1'
    assert_response :success
    assert_equal(@response.body, original_file)
    post '/source/home:tom/copied_service', cmd: 'copy', opackage: 'service', oproject: 'home:tom'
    assert_response :success
    get '/source/home:tom/copied_service?expand=1'
    assert_response :success
    assert_xml_tag tag: "entry", attributes: { name: "_service:download_url:file" }
    get '/source/home:tom/copied_service/_service:download_url:file?expand=1'
    assert_response :success
    delete '/source/home:tom/copied_service'
    assert_response :success
    assert_not_equal(@response.body, original_file)

    # project copy tests
    post '/source/home:tom:COPY', cmd: 'copy', noservice: '1', oproject: 'home:tom'
    assert_response :success
    get '/source/home:tom:COPY/service?expand=1'
    assert_response :success
    assert_xml_tag tag: "entry", attributes: { name: "_service:download_url:file" }
    get '/source/home:tom:COPY/service/_service:download_url:file?expand=1'
    assert_response :success
    assert_equal(@response.body, original_file)
    post '/source/home:tom:COPY/service', cmd: 'copy', oproject: 'home:tom'
    assert_response :success
    get '/source/home:tom:COPY/service?expand=1'
    assert_response :success
    assert_xml_tag tag: "entry", attributes: { name: "_service:download_url:file" }
    get '/source/home:tom:COPY/service/_service:download_url:file?expand=1'
    assert_response :success
    assert_not_equal(@response.body, original_file)
    delete '/source/home:tom:COPY'
    assert_response :success

    # remove service
    put '/source/home:tom/service/_service', '<services/>' # empty list
    assert_response :success
    post '/source/home:tom/service?cmd=runservice'
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response :success
    get '/source/home:tom/service'
    assert_response :success
    assert_xml_tag tag: 'serviceinfo', attributes: { code: 'succeeded' }
    assert_no_xml_tag parent: { tag: 'serviceinfo' }, tag: 'error'
    get '/source/home:tom/service/_service:download_url:file?expand=1'
    assert_response 404

    # cleanup
    delete '/source/home:tom:branches:home:tom'
    assert_response :success
    delete '/source/home:tom/new_package'
    assert_response :success
    delete '/source/home:tom/service'
    assert_response :success

    # failure check
    login_king
    get '/source/BaseDistro2.0/pack2'
    assert_response :success
    get '/source/BaseDistro2.0/pack2/_service'
    assert_response 404
    post '/source/BaseDistro2.0/pack2?cmd=runservice'
    assert_response 404
  end

  def test_service_merge_invalid
    login_tom
    # Setup package
    put '/source/home:tom/service/_meta', "<package project='home:tom' name='service'> <title /> <description /> </package>"
    assert_response :success
    put '/source/home:tom/service/pack.spec', "# Comment \nName: pack\nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success

    put '/source/home:tom/service/_service', '<services> <service name="not_existing" /> </services>'
    assert_response :success
    assert_nil Package.find_by_project_and_name("home:tom", "service").backend_package.error
    post '/source/home:tom/service?cmd=runservice'
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    # we have waited, but service was not running successful
    assert_response 400
    get '/source/home:tom/service'
    assert_response :success
    assert_xml_tag tag: 'serviceinfo', attributes: { code: 'failed' }
    UpdateNotificationEvents.new.perform
    get '/source/home:tom/service?expand=1'
    assert_response 400
    assert_match(/not_existing/, @response.body) # multiple line error shows up
  end

  def test_service_merge_valid
    login_tom
    # Setup package
    put '/source/home:tom/service/_meta', "<package project='home:tom' name='service'> <title /> <description /> </package>"
    assert_response :success
    put '/source/home:tom/service/pack.spec', "# Comment \nName: pack\nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success

    put '/source/home:tom/service/_service',
        '<services> <service name="download_url" >
         <param name="host">localhost</param>
         <param name="path">/directory/subdirectory/file</param>
         </service> </services>'
    assert_response :success
    post '/source/home:tom/service?cmd=runservice'
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response :success

    get '/source/home:tom/service'
    assert_response :success
    assert_xml_tag tag: 'serviceinfo', attributes: { code: 'succeeded' }
    assert_no_xml_tag parent: { tag: 'serviceinfo' }, tag: 'error'
    get '/source/home:tom/service/_service:download_url:file?expand=1'
    assert_response :success
    post '/source/home:tom/service?cmd=mergeservice', nil
    assert_response :success
    get '/source/home:tom/service'
    assert_response :success
    # _service file got dropped
    get '/source/home:tom/service/_service'
    assert_response 404
    # result got commited as usual file
    get '/source/home:tom/service/file'
    assert_response :success
    # old file remained
    get '/source/home:tom/service/pack.spec'
    assert_response :success

    delete '/source/home:tom/service'
    assert_response :success
  end

  def test_buildtime_service
    login_Iggy
    put '/source/home:Iggy/service/_meta',
        "<package project='home:Iggy' name='service'> <title /> <description /> <build><enable/></build></package>"
    assert_response :success
    put '/source/home:Iggy/service/pack.spec', "# Comment \nName: pack\nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success

    post '/source/home:Iggy/service?cmd=waitservice'
    assert_response :success
    put '/source/home:Iggy/service/_service',
        '<services> <service name="set_version" mode="buildtime">
         <param name="version">0817</param>
         <param name="file">pack.spec</param>
         </service> </services>'
    assert_response :success
    post '/source/home:Iggy/service?cmd=waitservice'
    assert_response :success
    run_scheduler('i586')
    get '/build/home:Iggy/_result'
    assert_response :success
    assert_xml_tag tag: "details", content: "nothing provides obs-service-set_version"

    # osc local package build call
    get "/build/home:Iggy/10.2/i586/service/_buildinfo"
    assert_response :success
    assert_xml_tag tag: "error", content: "unresolvable: nothing provides obs-service-set_version"
    # osc local package build call sending own spec and _service file
    cpio=IO.popen("cd #{Rails.root}/test/fixtures/backend/source/buildtime_service_source/; exec ls -1 | cpio -H newc -o 2>/dev/null")
    raw_post "/build/home:Iggy/10.2/i586/service/_buildinfo", cpio.read
    assert_response :success
    assert_xml_tag tag: "error", content: "unresolvable: nothing provides obs-service-recompresserator"

    delete '/source/home:Iggy/service'
    assert_response :success
  end

  def test_source_commit_with_service
    login_tom
    put '/source/home:tom/service/_meta', "<package project='home:tom' name='service'> <title /> <description /> </package>"
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response :success
    put '/source/home:tom/service/_service',
        '<services> <service name="set_version" >
         <param name="version">0819</param>
         <param name="file">pack.spec</param> </service> </services>'
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response :success
    put '/source/home:tom/service/pack.spec', "# Comment \nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response :success

    # find out the md5sum of _service file
    get '/source/home:tom/service'
    assert_response :success
    doc = REXML::Document.new(@response.body)
    md5sum_service = doc.elements["//entry[@name='_service']"].attributes['md5']
    md5sum_spec = doc.elements["//entry[@name='pack.spec']"].attributes['md5']

    # do a commit to trigger the service
    put '/source/home:tom/service/filename?rev=repository', 'CONTENT'
    assert_response :success
    filelist = '<directory> <entry name="filename" md5="45685e95985e20822fb2538a522a5ccf" /> <entry name="_service" md5="' +
               md5sum_service + '" /> <entry name="pack.spec" md5="' + md5sum_spec + '" /> </directory> '
    raw_post '/source/home:tom/service?cmd=commitfilelist', filelist
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response :success

    get '/source/home:tom/service/_history'
    # do another commit, check that the service files are kept
    filelist = '<directory> <entry name="_service" md5="' + md5sum_service + '" /> <entry name="pack.spec" md5="' + md5sum_spec + '" /> </directory> '
    raw_post '/source/home:tom/service?cmd=commitfilelist', filelist
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response :success

    # validate revisions
    get '/source/home:tom/service/_history'
    assert_response :success
    get '/source/home:tom/service?rev=3&expand=1' # show service generated files
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: '_service:set_version:pack.spec' }
    assert_xml_tag tag: 'entry', attributes: { name: 'filename' }
    get '/source/home:tom/service?rev=4' # second commit
    assert_response :success
    assert_no_xml_tag tag: 'entry', attributes: { name: '_service:set_version:pack.spec' }
    assert_no_xml_tag tag: 'entry', attributes: { name: 'filename' } # user file got removed
    get '/source/home:tom/service?rev=4&expand=1' # with generated files
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: '_service:set_version:pack.spec' }
    assert_no_xml_tag tag: 'entry', attributes: { name: 'filename' }

    # cleanup
    delete '/source/home:tom/service'
    assert_response :success
  end

  def test_run_project_source_service
    login_tom
    put '/source/home:tom/service/_meta', "<package project='home:tom' name='service'> <title /> <description /> </package>"
    assert_response :success
    put '/source/home:tom/service/pack.spec', "# Comment \nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success

    # unknown service
    put '/source/home:tom/_project/_service', '<services> <service name="not_existing" /> </services>'
    assert_response :success
    post '/source/home:tom/service?cmd=runservice'
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response 400 # broken service
    get '/source/home:tom/service'
    assert_response :success
    assert_xml_tag tag: 'serviceinfo', attributes: { code: 'failed' }
    assert_match(/not_existing.service  No such file or directory/, @response.body)

    # unknown parameter
    put '/source/home:tom/_project/_service', '<services> <service name="set_version" > <param name="INVALID">0817</param></service> </services>'
    assert_response :success
    post '/source/home:tom/service?cmd=runservice'
    assert_response :success
    post '/source/home:tom/service?cmd=waitservice'
    assert_response 400 # broken service
    get '/source/home:tom/service'
    assert_response :success
    assert_xml_tag tag: 'serviceinfo', attributes: { code: 'failed' }
    assert_match(/service parameter &quot;INVALID&quot; is not defined/, @response.body)

    # invalid names
    put '/source/home:tom/_project/_service', '<services> <service name="set_version ; `ls`" ></service> </services>'
    assert_response 400
    assert_match(/service name.*contains invalid chars/, @response.body)
    put '/source/home:tom/_project/_service', '<services> <service name="../blahfasel" ></service> </services>'
    assert_response 400
    assert_match(/service name.*contains invalid chars/, @response.body)
    put '/source/home:tom/_project/_service', '<services> <service name="set_version" > <param name="asd; `ls`">0817</param></service> </services>'
    assert_response 400
    assert_match(/service parameter.*contains invalid chars/, @response.body)

    # reset
    put '/source/home:tom/_project/_service',
        '<services> <service name="set_version" > <param name="version">0817</param> <param name="file">pack.spec</param> </service> </services>'
    assert_response :success

    put '/source/home:tom/service2/_meta', "<package project='home:tom' name='service2'> <title /> <description /> </package>"
    assert_response :success
    put '/source/home:tom/service2/pack.spec', "# Comment \nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success
    post '/source/home:tom/service2?cmd=runservice'
    assert_response :success
    post '/source/home:tom/service2?cmd=waitservice'
    assert_response :success
    get '/source/home:tom/service2'
    assert_response :success
    assert_xml_tag tag: 'serviceinfo', attributes: { code: 'succeeded' }
    assert_no_xml_tag parent: { tag: 'serviceinfo' }, tag: 'error'
    get '/source/home:tom/service2/_service:set_version:pack.spec?expand=1'
    assert_response :success

    # cleanup
    delete '/source/home:tom/_project/_service'
    assert_response :success
    delete '/source/home:tom/service'
    assert_response :success
    delete '/source/home:tom/service2'
    assert_response :success
  end

  def test_run_service_via_token
    post '/person/tom/token?cmd=create'
    assert_response 401

    login_tom
    put '/source/home:tom/service/_meta', "<package project='home:tom' name='service'> <title /> <description /> </package>"
    assert_response :success

    post '/person/tom/token?cmd=create'
    assert_response :success
    doc = REXML::Document.new(@response.body)
    alltoken = doc.elements['//data'].text
    assert_equal 40, alltoken.length
    post '/person/tom/token?cmd=create&project=home:tom&package=service'
    assert_response :success
    doc = REXML::Document.new(@response.body)
    token = doc.elements['//data'].text
    assert_equal 40, token.length

    # ANONYMOUS
    reset_auth
    post '/person/tom/token?cmd=create'
    assert_response 401
    post '/person/tom/token?cmd=create&project=home:tom&package=service'
    assert_response 401
    post '/trigger/runservice'
    assert_response 403
    assert_xml_tag tag: 'status', attributes: { code: 'permission_denied' }
    assert_match(/No valid token found/, @response.body)

    # with wrong token
    post '/trigger/runservice', nil, { 'Authorization' => 'Token wrong' }
    assert_response 404
    assert_xml_tag tag: 'status', attributes: { code: 'not_found' }

    # with right token
    post '/trigger/runservice', nil, { 'Authorization' => "Token #{token}" }
    # success, but no source service configured :)
    assert_response 404
    assert_match(/no source service defined/, @response.body)

    # with global token
    post '/trigger/runservice?project=home:tom&package=service', nil, { 'Authorization' => "Token #{alltoken}" }
    # success, but no source service configured :)
    assert_response 404
    assert_match(/no source service defined/, @response.body)

    # Locking user blocks the trigger
    tom = User.find_by_login("tom")
    tom.state = "locked"
    tom.save!
    # with right token
    post '/trigger/runservice', nil, { 'Authorization' => "Token #{token}" }
    # success, but no source service configured :)
    assert_response 403
    assert_xml_tag tag: "status", attributes: { code: "no_permission" }
    # with global token
    post '/trigger/runservice?project=home:tom&package=service', nil, { 'Authorization' => "Token #{alltoken}" }
    # success, but no source service configured :)
    assert_response 403
    assert_xml_tag tag: "status", attributes: { code: "no_permission" }

    # reset and drop stuff as tom
    tom.state = "confirmed"
    tom.save!
    login_tom
    get '/person/tom/token'
    assert_response :success
    assert_xml_tag tag: 'directory', attributes: { count: '2' }
    assert_xml_tag tag: 'entry', attributes: { project: 'home:tom', package: 'service' }
    doc = REXML::Document.new(@response.body)
    id = doc.elements['//entry'].attributes['id']
    assert_not_nil id
    assert_not_nil doc.elements['//entry'].attributes['string']
    delete "/person/tom/token/#{id}"
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { code: 'ok' }
    delete "/person/tom/token/#{id}"
    assert_response 404
    get '/person/tom/token'
    assert_response :success
    assert_xml_tag tag: 'directory', attributes: { count: '1' }

    # cleanup
    delete '/source/home:tom/service'
    assert_response :success
  end
end
