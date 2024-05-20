require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'source_controller'

class ReleaseManagementTests < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    reset_auth
    Backend::Test.start(wait_for_scheduler: true)
  end

  def test_move_entire_project
    login_tom

    # try as non-admin
    post '/source/home:tom:BaseDistro', params: { cmd: :move, oproject: 'BaseDistro' }
    assert_response :forbidden

    login_king
    post '/source/home:tom', params: { cmd: :move, oproject: 'BaseDistro' }
    assert_response :bad_request

    # real move
    post '/source/TEMP:BaseDistro', params: { cmd: :move, oproject: 'BaseDistro' }
    assert_response :success
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })
    get '/source/TEMP:BaseDistro'
    assert_response :success
    get '/source/TEMP:BaseDistro/_project'
    assert_response :success
    get '/source/TEMP:BaseDistro/_project/_history?meta=1'
    assert_response :success
    assert_xml_tag tag: 'comment', content: 'Project move from BaseDistro to TEMP:BaseDistro'
    get '/source/TEMP:BaseDistro/pack2/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { project: 'TEMP:BaseDistro' }
    get '/build/TEMP:BaseDistro'
    assert_response :success
    get '/build/TEMP:BaseDistro/BaseDistro_repo/i586/pack2/package-1.0-1.i586.rpm'
    assert_response :success
    get '/source/BaseDistro'
    assert_response :not_found
    get '/build/BaseDistro'
    assert_response :not_found
    get '/build/BaseDistro/BaseDistro_repo/i586/pack2/package-1.0-1.i586.rpm'
    assert_response :not_found

    # move back
    post '/source/BaseDistro', params: { cmd: :move, oproject: 'TEMP:BaseDistro' }
    assert_response :success
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })
    get '/source/BaseDistro/pack2/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { project: 'BaseDistro' }
    get '/source/BaseDistro/_project/_history?meta=1'
    assert_response :success
    assert_xml_tag tag: 'comment', content: 'Project move from TEMP:BaseDistro to BaseDistro'
    get '/build/TEMP:BaseDistro'
    assert_response :not_found
    get '/build/TEMP:BaseDistro/BaseDistro_repo/i586/pack2/package-1.0-1.i586.rpm'
    assert_response :not_found
    get '/build/BaseDistro'
    assert_response :success
    get '/build/BaseDistro/BaseDistro_repo/i586/pack2/package-1.0-1.i586.rpm'
    assert_response :success
  end

  def test_release_project
    login_tom

    # inject a job for copy any entire project ... gets copied in testsuite but appears to be delayed
    post '/source/home:tom:BaseDistro', params: { cmd: :copy, oproject: 'BaseDistro' }
    assert_response :success
    assert_xml_tag(tag: 'status', attributes: { code: 'invoked' })

    # cleanup
    delete '/source/home:tom:BaseDistro'
    assert_response :success

    # copy any entire project NOW
    post '/source/home:tom:BaseDistro', params: { cmd: :copy, oproject: 'BaseDistro', nodelay: 1 }
    assert_response :success
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })

    # try a split
    post '/source/home:tom:BaseDistro', params: { cmd: :copy, oproject: 'BaseDistro', makeolder: 1 }
    assert_response :forbidden

    # cleanup
    delete '/source/home:tom:BaseDistro'
    assert_response :success

    get '/source/BaseDistro'
    assert_response :success
    packages = Xmlhash.parse(@response.body)
    vrevs = {}
    packages.elements('entry') do |p|
      get "/source/BaseDistro/#{p['name']}"
      assert_response :success
      files = Xmlhash.parse(@response.body)
      vrevs[p['name']] = files['vrev']
    end
    assert_not_equal vrevs.count, 0

    # make a full split as admin
    login_king
    post '/source/TEST:BaseDistro', params: { cmd: :copy, oproject: 'BaseDistro', makeolder: 1, nodelay: 1 }
    assert_response :success

    # the origin must got increased by 2 behind a possible dot
    vrevs.each_key do |k|
      get "/source/BaseDistro/#{k}"
      assert_response :success
      files = Xmlhash.parse(@response.body)
      revision_parts = vrevs[k].to_s.split(/(.*\.)([^.]*)$/)
      expectedvrev = (revision_parts[0].to_i + 2).to_s # no dot inside of vrev as fallback
      expectedvrev = "#{revision_parts[1]}#{revision_parts[2].to_i + 2}" if revision_parts.count > 1
      assert_equal expectedvrev, files['vrev']
    end

    # the copy must have a vrev by one higher and an extended .1
    vrevs.each_key do |k|
      get "/source/TEST:BaseDistro/#{k}"
      assert_response :success
      files = Xmlhash.parse(@response.body)
      assert_equal "#{vrevs[k].to_i + 1}.1", files['vrev']
    end

    # cleanup
    delete '/source/TEST:BaseDistro'
    assert_response :success

    # test again with history copy
    post '/source/TEST:BaseDistro', params: { cmd: :copy, oproject: 'BaseDistro', makeolder: 1, nodelay: 1, withhistory: 1 }
    assert_response :success

    # the origin must got increased by another 2
    vrevs.each_key do |k|
      get "/source/BaseDistro/#{k}"
      assert_response :success
      files = Xmlhash.parse(@response.body)
      assert_equal (vrevs[k].to_i + 4).to_s, files['vrev']
    end

    # the copy must have a vrev by 3 higher and an extended .1
    vrevs.each_key do |k|
      get "/source/TEST:BaseDistro/#{k}"
      assert_response :success
      files = Xmlhash.parse(@response.body)
      assert_equal "#{vrevs[k].to_i + 3}.1", files['vrev']
    end

    # cleanup
    delete '/source/TEST:BaseDistro'
    assert_response :success
  end

  def test_copy_project_withbinaries
    login_king

    put '/source/home:Iggy/TestPack/dummy_change', params: 'trigger build'
    assert_response :success
    run_scheduler('i586')
    run_scheduler('x86_64')
    inject_build_job('home:Iggy', 'TestPack', '10.2', 'i586')
    inject_build_job('home:Iggy', 'TestPack', '10.2', 'x86_64')
    run_scheduler('i586')
    run_scheduler('x86_64')
    run_publisher

    # prerequisite: is our source project setup correctly?
    get '/build/home:Iggy/10.2/i586/TestPack'
    assert_xml_tag tag: 'binarylist', children: { count: 4 }
    get '/build/home:Iggy/10.2/x86_64/TestPack'
    assert_xml_tag tag: 'binarylist', children: { count: 5 }

    # our source project is not building
    get '/build/home:Iggy/_result'
    assert_xml_tag parent: {
                     tag: 'result',
                     attributes: { project: 'home:Iggy',
                                   repository: '10.2',
                                   arch: 'i586',
                                   code: 'published',
                                   state: 'published' }
                   },
                   tag: 'status',
                   attributes: { package: 'TestPack',
                                 code: 'succeeded' }
    assert_xml_tag parent: {
                     tag: 'result',
                     attributes: { project: 'home:Iggy',
                                   repository: '10.2',
                                   arch: 'x86_64',
                                   code: 'published',
                                   state: 'published' }
                   },
                   tag: 'status', attributes: { package: 'TestPack',
                                                code: 'succeeded' }

    # copy project with binaries
    post '/source/IggyHomeCopy?cmd=copy&oproject=home:Iggy&noservice=1&withbinaries=1&nodelay=1'
    assert_response :success

    # let scheduler process events...
    run_scheduler('i586')
    run_scheduler('x86_64')
    run_publisher

    # get copy project meta and verify copied repositories
    get '/source/IggyHomeCopy/_meta'
    assert_response :success

    assert_xml_tag parent: { tag: 'project', attributes: { name: 'IggyHomeCopy' } },
                   tag: 'repository', attributes: { name: '10.2' }

    assert_xml_tag parent: { tag: 'repository', attributes: { name: '10.2' } },
                   tag: 'path', attributes: { project: 'BaseDistro', repository: 'BaseDistro_repo' }

    assert_xml_tag parent: { tag: 'repository', attributes: { name: '10.2' } },
                   tag: 'arch', content: 'i586'

    assert_xml_tag parent: { tag: 'repository', attributes: { name: '10.2' } },
                   tag: 'arch', content: 'x86_64'

    # check build results are copied correctly
    get '/build/IggyHomeCopy/_result'
    assert_xml_tag parent: {
                     tag: 'result',
                     attributes: { project: 'IggyHomeCopy',
                                   repository: '10.2',
                                   arch: 'i586',
                                   code: 'published',
                                   state: 'published' }
                   },
                   tag: 'status',
                   attributes: { package: 'TestPack', code: 'succeeded' }

    assert_xml_tag parent: {
                     tag: 'result',
                     attributes: { project: 'IggyHomeCopy',
                                   repository: '10.2',
                                   arch: 'x86_64',
                                   code: 'published',
                                   state: 'published' }
                   },
                   tag: 'status',
                   attributes: { package: 'TestPack', code: 'succeeded' }

    # check that the same binaries are copied
    get '/build/home:Iggy/10.2/i586/TestPack'
    assert_xml_tag tag: 'binarylist', children: { count: 4 }
    get '/build/IggyHomeCopy/10.2/i586/TestPack'
    assert_xml_tag tag: 'binarylist', children: { count: 4 }
    get '/build/home:Iggy/10.2/x86_64/TestPack'
    assert_xml_tag tag: 'binarylist', children: { count: 5 }
    get '/build/IggyHomeCopy/10.2/x86_64/TestPack'
    assert_xml_tag tag: 'binarylist', children: { count: 5 }

    # cleanup
    delete '/source/home:Iggy/TestPack/dummy_change'
    assert_response :success
    delete '/source/IggyHomeCopy'
    assert_response :success
  end
end
