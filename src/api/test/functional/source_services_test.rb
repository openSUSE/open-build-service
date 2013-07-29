require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class SourceServicesTest < ActionDispatch::IntegrationTest 
  fixtures :all
  
  def test_get_servicelist
    get "/service"
    assert_response 401

    prepare_request_with_user "tom", "thunder"
    get "/service"
    assert_response :success
    assert_xml_tag :tag => "servicelist"

    # not using assert_xml_tag for doing a propper error message on missing 
    # source service packages
    download_url = set_version = download_files = nil
    services = ActiveXML::Node.new(@response.body)
    services.each_service do |s|
      if s.name == "download_url"
        download_url = 1
      end
      if s.name == "download_files"
        download_files = 1
      end
      if s.name == "set_version"
        set_version = 1
      end
    end
    assert_xml_tag :tag => "service", :attributes => { :name => "set_version" }
    assert_xml_tag :tag => "service", :attributes => { :name => "download_url" }
    assert_xml_tag :tag => "service", :attributes => { :name => "download_files" }
  end

  def test_combine_project_service_list
    prepare_request_with_user "king", "sunflower"

    raw_put "/source/BaseDistro2.0/_project/_service", '<services> <service name="set_version" > <param name="version">0815</param> </service> </services>'
    assert_response :success
    raw_put "/source/BaseDistro2.0:LinkedUpdateProject/_project/_service", '<services> <service name="download_files" /> </services>'
    assert_response :success

    prepare_request_with_user "tom", "thunder"
    post "/source/BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "branch"
    assert_response :success
    raw_put "/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/_project/_service", '<services> <service name="download_url" > <param name="host">blahfasel</param> </service> </services>'
    assert_response :success

    post "/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject/pack2", :cmd => "getprojectservices"
    assert_response :success
    assert_xml_tag( :tag => "service", :attributes => { :name => "download_files" } )
    assert_xml_tag( :parent => { :tag => "service", :attributes => { :name => "download_url" } }, :tag => "param", :attributes => { :name => "host"}, :content => "blahfasel" )
    assert_xml_tag( :parent => { :tag => "service", :attributes => { :name => "set_version" } }, :tag => "param", :attributes => { :name => "version"}, :content => "0815" )

    # cleanup
    prepare_request_with_user "king", "sunflower"
    delete "/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject"
    assert_response :success
    delete "/source/BaseDistro2.0/_project/_service"
    assert_response :success
    delete "/source/BaseDistro2.0:LinkedUpdateProject/_project/_service"
    assert_response :success
  end

  def wait_for_service( project, package )
    i=0
    while true
      get "/source/#{project}/#{package}"
      assert_response :success
      node = ActiveXML::Node.new(@response.body)
      return unless node.has_element? "serviceinfo" 
      return if [ "failed", "succeeded" ].include? node.serviceinfo.code # else "running"
      i=i+1
      if i > 10
        puts "ERROR in wait_for_service: service did not run until time limit"
        exit 1
      end
      sleep 0.5
    end
  end

  def test_run_source_service
    prepare_request_with_user "tom", "thunder"
    raw_put "/source/home:tom/service/_meta", "<package project='home:tom' name='service'> <title /> <description /> </package>"
    assert_response :success
    raw_put "/source/home:tom/service/pack.spec", "# Comment \nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success

    raw_put "/source/home:tom/service/_service", '<services> <service name="not_existing" /> </services>'
    assert_response :success
    post "/source/home:tom/service?cmd=runservice"
    assert_response :success
    wait_for_service( "home:tom", "service" )
    get "/source/home:tom/service"
    assert_response :success
    assert_xml_tag :tag => "serviceinfo", :attributes => { :code => 'failed' }
    get "/source/home:tom/service?expand=1"
    assert_response 400
    assert_match(/not_existing/, @response.body) # multiple line error shows up

    raw_put "/source/home:tom/service/_service", '<services> <service name="set_version" > <param name="version">0816</param> <param name="file">pack.spec</param> </service> </services>'
    assert_response :success
    post "/source/home:tom/service?cmd=runservice"
    assert_response :success
    wait_for_service( "home:tom", "service" )
    get "/source/home:tom/service"
    assert_response :success
    assert_xml_tag :tag => "serviceinfo", :attributes => { :code => 'succeeded' }
    assert_no_xml_tag :parent => { :tag => "serviceinfo" }, :tag => "error"
    get "/source/home:tom/service/_service:set_version:pack.spec?expand=1"
    assert_response :success
    post "/source/home:tom/service?cmd=servicediff", nil
    assert_match(/\+Version: 0816/, @response.body)
    assert_response :success

    # submit to other package
    raw_post "/request?cmd=create", '<request>
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
    get "/source/home:tom/new_package"
    assert_response :success
    assert_xml_tag :tag => "serviceinfo", :attributes => { :code => 'succeeded' }
    assert_no_xml_tag :parent => { :tag => "serviceinfo" }, :tag => "error"
    get "/source/home:tom/new_package/_service:set_version:pack.spec?expand=1"
    assert_response :success

    # branch and submit requsts
    post "/source/home:tom/service", :cmd => "branch"
    assert_response :success
    put "/source/home:tom:branches:home:tom/service/new_file", "content"
    assert_response :success
    wait_for_service( "home:tom:branches:home:tom", "service" )
    get "/source/home:tom:branches:home:tom/service/_service:set_version:pack.spec?expand=1"
    assert_response :success
    post "/request?cmd=create", '<request>
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
    get "/source/home:tom:branches:home:tom/service/_service:set_version:pack.spec?expand=1"
    assert_response :success
    get "/source/home:tom/service/_service:set_version:pack.spec?expand=1"
    assert_response :success

    # remove service
    put "/source/home:tom/service/_service", '<services/>' # empty list
    assert_response :success
    post "/source/home:tom/service?cmd=runservice"
    assert_response :success
    wait_for_service( "home:tom", "service" )
    get "/source/home:tom/service"
    assert_response :success
    assert_xml_tag :tag => "serviceinfo", :attributes => { :code => 'succeeded' }
    assert_no_xml_tag :parent => { :tag => "serviceinfo" }, :tag => "error"
    get "/source/home:tom/service/_service:set_version:pack.spec?expand=1"
    assert_response 404

    # cleanup
    delete "/source/home:tom:branches:home:tom"
    assert_response :success
    delete "/source/home:tom/new_package"
    assert_response :success
    delete "/source/home:tom/service"
    assert_response :success

    # failure check
    prepare_request_with_user "king", "sunflower"
    get "/source/BaseDistro2.0/pack2"
    assert_response :success
    get "/source/BaseDistro2.0/pack2/_service"
    assert_response 404
    post "/source/BaseDistro2.0/pack2?cmd=runservice"
    assert_response 404
  end

  def test_source_commit_with_service
    prepare_request_with_user "tom", "thunder"
    put "/source/home:tom/service/_meta", "<package project='home:tom' name='service'> <title /> <description /> </package>"
    assert_response :success
    put "/source/home:tom/service/_service", '<services> <service name="set_version" > <param name="version">0819</param> <param name="file">pack.spec</param> </service> </services>'
    assert_response :success
    wait_for_service( "home:tom", "service" )
    put "/source/home:tom/service/pack.spec", "# Comment \nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success
    wait_for_service( "home:tom", "service" )

    # find out the md5sum of _service file
    get "/source/home:tom/service"
    assert_response :success
    doc = REXML::Document.new(@response.body)
    md5sum_service = doc.elements["//entry[@name='_service']"].attributes['md5']
    md5sum_spec = doc.elements["//entry[@name='pack.spec']"].attributes['md5']

    # do a commit to trigger the service
    put "/source/home:tom/service/filename?rev=repository", 'CONTENT'
    assert_response :success
    filelist = '<directory> <entry name="filename" md5="45685e95985e20822fb2538a522a5ccf" /> <entry name="_service" md5="' + md5sum_service + '" /> <entry name="pack.spec" md5="' + md5sum_spec + '" /> </directory> '
    raw_post "/source/home:tom/service?cmd=commitfilelist", filelist
    assert_response :success
    wait_for_service( "home:tom", "service" )

    get "/source/home:tom/service/_history"
    # do another commit, check that the service files are kept
    filelist = '<directory> <entry name="_service" md5="' + md5sum_service + '" /> <entry name="pack.spec" md5="' + md5sum_spec + '" /> </directory> '
    raw_post "/source/home:tom/service?cmd=commitfilelist", filelist
    assert_response :success
    wait_for_service( "home:tom", "service" )

    # validate revisions
    get "/source/home:tom/service/_history"
    assert_response :success
    get "/source/home:tom/service?rev=3&expand=1" # show service generated files
    assert_response :success
    assert_xml_tag :tag => 'entry', :attributes => { :name => '_service:set_version:pack.spec' }
    assert_xml_tag :tag => 'entry', :attributes => { :name => 'filename' }
    get "/source/home:tom/service?rev=4" # second commit
    assert_response :success
    assert_no_xml_tag :tag => 'entry', :attributes => { :name => '_service:set_version:pack.spec' }
    assert_no_xml_tag :tag => 'entry', :attributes => { :name => 'filename' }                      # user file got removed
    get "/source/home:tom/service?rev=4&expand=1" # with generated files
    assert_response :success
    assert_xml_tag :tag => 'entry', :attributes => { :name => '_service:set_version:pack.spec' }
    assert_no_xml_tag :tag => 'entry', :attributes => { :name => 'filename' }

    # cleanup
    delete "/source/home:tom/service"
    assert_response :success
  end

  def test_run_project_source_service
    prepare_request_with_user "tom", "thunder"
    put "/source/home:tom/service/_meta", "<package project='home:tom' name='service'> <title /> <description /> </package>"
    assert_response :success
    put "/source/home:tom/service/pack.spec", "# Comment \nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success

    put "/source/home:tom/_project/_service", '<services> <service name="not_existing" /> </services>'
    assert_response :success
    post "/source/home:tom/service?cmd=runservice"
    assert_response :success
    wait_for_service( "home:tom", "service" )
    get "/source/home:tom/service"
    assert_response :success
    assert_xml_tag :tag => "serviceinfo", :attributes => { :code => 'failed' }

    put "/source/home:tom/_project/_service", '<services> <service name="set_version" > <param name="version">0817</param> <param name="file">pack.spec</param> </service> </services>'
    assert_response :success

    put "/source/home:tom/service2/_meta", "<package project='home:tom' name='service2'> <title /> <description /> </package>"
    assert_response :success
    put "/source/home:tom/service2/pack.spec", "# Comment \nVersion: 12\nRelease: 9\nSummary: asd"
    assert_response :success
    post "/source/home:tom/service2?cmd=runservice"
    assert_response :success
    wait_for_service( "home:tom", "service2" )
    get "/source/home:tom/service2"
    assert_response :success
    assert_xml_tag :tag => "serviceinfo", :attributes => { :code => 'succeeded' }
    assert_no_xml_tag :parent => { :tag => "serviceinfo" }, :tag => "error"
    get "/source/home:tom/service2/_service:set_version:pack.spec?expand=1"
    assert_response :success

    # cleanup
    delete "/source/home:tom/_project/_service"
    assert_response :success
    delete "/source/home:tom/service"
    assert_response :success
    delete "/source/home:tom/service2"
    assert_response :success
  end

end
