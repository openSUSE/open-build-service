require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class ReleaseManagementTests < ActionDispatch::IntegrationTest 
  fixtures :all

  def setup
    reset_auth
    wait_for_scheduler_start
  end

  def test_release_project
    login_tom

    # inject a job for copy any entire project ... gets copied in testsuite but appears to be delayed
    post "/source/home:tom:BaseDistro", :cmd => :copy, :oproject => "BaseDistro"
    assert_response :success
    assert_xml_tag( :tag => "status", :attributes => { :code => "invoked"} )

    # cleanup
    delete "/source/home:tom:BaseDistro"
    assert_response :success

    # copy any entire project NOW
    post "/source/home:tom:BaseDistro", :cmd => :copy, :oproject => "BaseDistro", :nodelay => 1
    assert_response :success
    assert_xml_tag( :tag => "status", :attributes => { :code => "ok"} )

    # try a split
    post "/source/home:tom:BaseDistro", :cmd => :copy, :oproject => "BaseDistro", :makeolder => 1
    assert_response 403

    #cleanup
    delete "/source/home:tom:BaseDistro"
    assert_response :success

    get "/source/BaseDistro"
    assert_response :success
    packages = ActiveXML::Node.new(@response.body)
    vrevs = {}
    packages.each(:entry) do |p|
      get "/source/BaseDistro/#{p.value(:name)}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      vrevs[p.value(:name)] = files.value(:vrev)
    end
    assert_not_equal vrevs.count, 0

    # make a full split as admin
    login_king
    post "/source/TEST:BaseDistro", :cmd => :copy, :oproject => "BaseDistro", :makeolder => 1, :nodelay => 1
    assert_response :success

    # the origin must got increased by 2
    vrevs.each_key do |k|
      get "/source/BaseDistro/#{k}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      assert_equal "#{vrevs[k].to_i+2}", files.value(:vrev)
    end

    # the copy must have a vrev by one higher and an extended .1
    vrevs.each_key do |k|
      get "/source/TEST:BaseDistro/#{k}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      assert_equal "#{vrevs[k].to_i+1}.1", files.value(:vrev)
    end

    #cleanup
    delete "/source/TEST:BaseDistro"
    assert_response :success

    # test again with history copy
    post "/source/TEST:BaseDistro", :cmd => :copy, :oproject => "BaseDistro", :makeolder => 1, :nodelay => 1, :withhistory => 1
    assert_response :success

    # the origin must got increased by another 2
    vrevs.each_key do |k|
      get "/source/BaseDistro/#{k}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      assert_equal "#{vrevs[k].to_i+4}", files.value(:vrev)
    end

    # the copy must have a vrev by 3 higher and an extended .1
    vrevs.each_key do |k|
      get "/source/TEST:BaseDistro/#{k}"
      assert_response :success
      files = ActiveXML::Node.new(@response.body)
      assert_equal "#{vrevs[k].to_i+3}.1", files.value(:vrev)
    end

    #cleanup
    delete "/source/TEST:BaseDistro"
    assert_response :success
  end

  def test_copy_project_withbinaries
    login_king

    run_scheduler('i586')
    run_scheduler('x86_64')
    inject_build_job( 'home:Iggy', 'TestPack', '10.2', 'i586')
    inject_build_job( 'home:Iggy', 'TestPack', '10.2', 'x86_64')
    run_scheduler('i586')
    run_scheduler('x86_64')
    wait_for_publisher()

    # prerequisite: is our source project setup correctly?
    get '/build/home:Iggy/10.2/i586/TestPack'
    assert_xml_tag :tag => 'binarylist', :children => { :count => 4 }
    get '/build/home:Iggy/10.2/x86_64/TestPack'
    assert_xml_tag :tag => 'binarylist', :children => { :count => 5 }

    # our source project is not building
    get '/build/home:Iggy/_result'
    assert_xml_tag :parent => { tag: 'result',
                                :attributes => { project:    'home:Iggy',
                                                 repository: '10.2',
                                                 arch:       'i586',
                                                 code:       'published',
                                                 state:      'published' }
      },
      tag: 'status',
      :attributes => { package: 'TestPack',
                       code:    'succeeded' }
    assert_xml_tag :parent => {
        tag: 'result',
        :attributes => { project:    'home:Iggy',
                         repository: '10.2',
                         arch:       'x86_64',
                         code:       'published',
                         state:      'published' } },
      :tag => 'status', :attributes => { package: 'TestPack',
                                         code:    'succeeded' }

    # copy project with binaries
    post '/source/IggyHomeCopy?cmd=copy&oproject=home:Iggy&noservice=1&withbinaries=1&nodelay=1'
    assert_response :success

    # let scheduler process events...
    run_scheduler('i586')
    run_scheduler('x86_64')
    wait_for_publisher()

    # get copy project meta and verify copied repositories
    get '/source/IggyHomeCopy/_meta'
    assert_response :success

    assert_xml_tag :parent => { :tag => 'project', :attributes => { :name => 'IggyHomeCopy' } },
      :tag => 'repository', :attributes => { :name => '10.2' }

    assert_xml_tag :parent => { :tag => 'repository', :attributes => { :name => '10.2' } },
      :tag => 'path', :attributes => { :project => 'BaseDistro', :repository => 'BaseDistro_repo' }

    assert_xml_tag :parent => { :tag => 'repository', :attributes => { :name => '10.2' } },
      :tag => 'arch', :content => 'i586'

    assert_xml_tag :parent => { :tag => 'repository', :attributes => { :name => '10.2' } },
      :tag => 'arch', :content => 'x86_64'

    # check build results are copied correctly
    get '/build/IggyHomeCopy/_result'
    assert_xml_tag :parent => {
                   tag: 'result',
                   :attributes => { project:    'IggyHomeCopy',
                                    repository: '10.2',
                                    arch:       'i586',
                                    code:       'published',
                                    state:      'published' } },
      tag: 'status',
      :attributes => { package: 'TestPack', code: 'succeeded' }

    assert_xml_tag :parent => {
                                tag: 'result',
                                :attributes => { project:    'IggyHomeCopy',
                                                 repository: '10.2',
                                                 arch:       'x86_64',
                                                 code:       'published',
                                                 state:      'published' }
        },
        tag: 'status',
        :attributes => { package: 'TestPack', code: 'succeeded' }

    # check that the same binaries are copied
    get '/build/home:Iggy/10.2/i586/TestPack'
    assert_xml_tag :tag => 'binarylist', :children => { :count => 4 }
    get '/build/IggyHomeCopy/10.2/i586/TestPack'
    assert_xml_tag :tag => 'binarylist', :children => { :count => 4 }
    get '/build/home:Iggy/10.2/x86_64/TestPack'
    assert_xml_tag :tag => 'binarylist', :children => { :count => 5 }
    get '/build/IggyHomeCopy/10.2/x86_64/TestPack'
    assert_xml_tag :tag => 'binarylist', :children => { :count => 5 }

    # cleanup
    delete '/source/IggyHomeCopy'
    assert_response :success
  end
end
