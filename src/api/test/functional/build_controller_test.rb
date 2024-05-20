require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class BuildControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    prepare_request_valid_user
    Backend::Test.start(wait_for_scheduler: true)
  end

  def test_index
    get '/build'
    assert_response :success
    assert_match(/entry name="home:Iggy"/, @response.body)
    get '/build/home:Iggy'
    assert_response :success
    assert_match(/entry name="10.2"/, @response.body)
    get '/build/home:Iggy/10.2'
    assert_response :success
    assert_match(/entry name="i586"/, @response.body)
    get '/build/home:Iggy/10.2/i586'
    assert_response :success
    assert_match(/entry name="TestPack"/, @response.body)
    get '/build/home:Iggy/10.2/i586/TestPack'
    assert_response :success
    assert_match(/binary filename="package-1.0-1.i586.rpm"/, @response.body)

    # FIXME: hope this is not 400 because its another hidden OBS interconnect case
    get '/build/blabla'
    assert_response :not_found
    get '/build/home:Iggy/blabla'
    assert_response :not_found
    get '/build/home:Iggy/10.2/blabla'
    assert_response :not_found
  end

  def test_upload_binaries
    reset_auth
    post '/build/home:Iggy/10.2/i586/TestPack'
    assert_response :unauthorized

    login_adrian
    post '/build/home:Iggy/10.2/i586/TestPack'
    assert_response :forbidden
    put '/build/home:Iggy/10.2/i586/_repository/rpm.rpm', params: '/dev/null'
    assert_response :forbidden

    login_king
    post '/build/home:Iggy/10.2/i586/TestPack'
    assert_response :bad_request # actually a success, it reached the backend
    assert_xml_tag tag: 'status', attributes: { code: '400', origin: 'backend' }

    put '/build/home:Iggy/10.2/i586/_repository/rpm.rpm', params: '/dev/null'
    assert_response :ok

    # check not supported methods
    post '/build/home:Iggy/10.2/i586/_repository'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_package' }
    put '/build/home:Iggy/10.2/i586/TestPack'
    assert_response :not_found # no such route

    delete '/build/home:Iggy/10.2/i586/TestPack'
    assert_response :not_found # no such route
  end

  def test_dispatchprios
    reset_auth
    get '/build/_dispatchprios'
    assert_response :unauthorized

    login_adrian
    get '/build/_dispatchprios'
    assert_response :success
    put '/build/_dispatchprios',
        params: ' <dispatchprios> <prio project="KDE:Distro:Factory" repository="openSUSE_Factory" adjust="7" /> </dispatchprios>'
    assert_response :forbidden

    login_king
    put '/build/_dispatchprios',
        params: ' <dispatchprios> <prio project="KDE:Distro:Factory" repository="openSUSE_Factory" adjust="7" /> </dispatchprios>'
    assert_response :success
  end

  def test_read_from_repository
    reset_auth
    login_adrian
    get '/build/home:Iggy/10.2/i586/_repository/not_existing.rpm'
    assert_response :not_found
    get '/build/home:Iggy/10.2/i586/TestPack/package-1.0-1.i586.rpm'
    assert_response :success
    get '/source/home:Iggy/TestPack/_meta'
    assert_response :success
    assert_xml_tag parent: { tag: 'build' }, tag: 'enable', attributes: { arch: 'i586', repository: '10.2' }
    # ensure that current state got written
    run_scheduler('i586')
    get '/build/home:Iggy/10.2/i586/TestPack/_status'
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { package: 'TestPack', code: 'succeeded' }
    get '/build/home:Iggy/10.2/i586/TestPack/_jobstatus'
    assert_response :success
    assert_xml_tag tag: 'jobstatus'
    get '/build/home:Iggy/10.2/i586/TestPack/_statistics'
    assert_response :success
    get '/build/home:Iggy/10.2/i586/_repository'
    assert_response :success
    assert_xml_tag tag: 'binarylist', child: { tag: 'binary' }
    assert_xml_tag tag: 'binary', attributes: { filename: 'package.rpm' }
    get '/build/home:Iggy/10.2/i586/_repository/package.rpm'
    assert_response :success
    get '/build/home:Iggy/10.2/i586/_repository?binary=rpm&binary=package&view=cpio'
    assert_response :success
    ret = IO.popen('cpio -t 2>/dev/null', 'r+') do |f|
      f.puts @response.body
      f.close_write
      f.gets
    end
    assert_match(/package.rpm/, ret)
    assert_no_match(/_statistics/, ret)
    get '/build/home:Iggy/10.2/i586/_repository/_statistics'
    assert_response :not_found
  end

  def test_delete_from_repository
    reset_auth
    delete '/build/home:Iggy/10.2/i586/_repository/delete_me.rpm'
    assert_response :unauthorized

    login_adrian
    delete '/build/home:Iggy/10.2/i586/_repository/delete_me.rpm'
    assert_response :forbidden
    delete '/build/home:Iggy/10.2/i586/_repository/not_existing.rpm'
    assert_response :forbidden
    get '/build/home:Iggy/10.2/i586/_repository/delete_me.rpm'
    assert_response :success

    login_Iggy
    delete '/build/home:Iggy/10.2/i586/_repository/delete_me.rpm'
    assert_response :success
    delete '/build/home:Iggy/10.2/i586/_repository/not_existing.rpm'
    assert_response :not_found
    get '/build/home:Iggy/10.2/i586/_repository/delete_me.rpm'
    assert_response :not_found

    delete '/build/home:Iggy/10.2/i586/TestPack/package-1.0-1.i586.rpm'
    assert_response :bad_request
    assert_match(/invalid_operation/, @response.body)
    assert_match(/Delete operation of build results is not allowed/, @response.body)
  end

  def test_buildinfo
    # just testing routing
    get '/build/buildinfo'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)

    # get source info to compare with
    get '/source/home:Iggy/TestPack'
    assert_response :success
    assert_no_xml_tag tag: 'xsrcmd5' # is no link, srcmd5 is valid
    srcmd5 = Xmlhash.parse(@response.body)['srcmd5']

    # osc local package build call
    get '/source/home:Iggy/TestPack/TestPack.spec'
    assert_response :success
    raw_post '/build/home:Iggy/10.2/i586/_repository/_buildinfo', @response.body
    assert_response :success

    # this is only testing the rep server buildinfo, not the one generated by scheduler
    get '/build/home:Iggy/10.2/i586/TestPack/_buildinfo'
    assert_response :success
    rev = '2'
    b_cnt = '2'
    ci_cnt = '42'
    assert_xml_tag tag: 'buildinfo'
    assert_xml_tag tag: 'arch', content: 'i586'
    assert_xml_tag tag: 'srcmd5', content: srcmd5
    assert_xml_tag tag: 'file', content: 'TestPack.spec'
    assert_xml_tag tag: 'debuginfo', content: '0'
    assert_xml_tag tag: 'release', content: "#{ci_cnt}.#{b_cnt}"
    assert_xml_tag tag: 'versrel', content: "1.0-#{ci_cnt}"
    assert_xml_tag tag: 'rev', content: rev
    assert_xml_tag tag: 'path', attributes: { project: 'home:Iggy', repository: '10.2' }
    # buildinfo = Xmlhash.parse(@response.body)

    # find scheduler job and compare it with buildinfo
    # FIXME: to be implemented, compare scheduler job with rep server job
    #   jobfile=File.new("#{ENV['OBS_BACKEND_TEMP']}/data/jobs/i586/home:Iggy::10.2::TestPack-#{srcmd5}")
    #   schedulerjob = Document.new(jobfile).root
    #   schedulerjob.elements.each do |jobnode|
    #     puts "test", jobnode.inspect
    #   end
  end

  def test_builddepinfo
    get '/build/home:Iggy/10.2/i586/_builddepinfo'
    assert_response :success
    assert_xml_tag parent: { tag: 'package', attributes: { name: 'TestPack' } }, tag: 'source', content: 'TestPack'
    assert_xml_tag parent: { tag: 'package', attributes: { name: 'TestPack' } }, tag: 'subpkg', content: 'TestPack'

    get '/build/HiddenProject/nada/i586/_builddepinfo'
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'unknown_project' })

    login_adrian
    get '/build/HiddenProject/nada/i586/_builddepinfo'
    assert_response :success

    # the webui is calling this with invalid package name to get the cycles only
    get '/build/home:Iggy/10.2/i586/_builddepinfo?package=-'
    assert_response :success
    assert_no_xml_tag parent: { tag: 'package', attributes: { name: 'TestPack' } }, tag: 'source'
    assert_no_xml_tag parent: { tag: 'package', attributes: { name: 'TestPack' } }, tag: 'subpkg'

    # for osc project build feature
    get '/build/HiddenProject/nada/i586/_builddepinfo?view=order'
    assert_response :success
    assert_xml_tag parent: { tag: 'builddepinfo' }, tag: 'package', attributes: { name: 'pack' }
    data = @response.body

    post '/build/HiddenProject/nada/i586/_builddepinfo?view=order', params: data
    assert_response :success
    assert_xml_tag parent: { tag: 'builddepinfo' }, tag: 'package', attributes: { name: 'pack' }
  end

  def test_package_index
    get '/build/home:Iggy/10.2/i586/TestPack'
    assert_response :success
    assert_xml_tag(tag: 'binarylist')
  end

  def test_read_access_hidden_package_index
    get '/build/HiddenProject/nada/i586/pack'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)
    # retry with maintainer
    login_adrian
    get '/build/HiddenProject/nada/i586/pack'
    assert_response :success
    assert_xml_tag(tag: 'binarylist')
    prepare_request_valid_user
  end

  def test_logfile
    get '/build/home:Iggy/10.2/i586/TestPack/_log'
    assert_response :success
    get '/build/home:Iggy/10.2/i586/notthere/_log'
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)
  end

  def test_multibuild_routes
    get '/build/BaseDistro3/BaseDistro3_repo/i586/pack2:package_multibuild'
    assert_response :success
    assert_xml_tag(tag: 'binary', parent: { tag: 'binarylist' })
    get '/build/BaseDistro3/BaseDistro3_repo/i586/pack2:package_multibuild/_log'
    assert_response :success
    get '/build/BaseDistro3/BaseDistro3_repo/i586/pack2:package_multibuild/package-1.0-1.src.rpm'
    assert_response :success
    get '/build/BaseDistro3/BaseDistro3_repo/i586/pack2:package_multibuild/_buildinfo'
    assert_response :success
    assert_xml_tag(tag: 'buildinfo')

    # backend bug?
    #    get "/build/BaseDistro3/BaseDistro3_repo/i586/pack2:package_multibuild_not_here"
    #    assert_response 404
    get '/build/BaseDistro3/BaseDistro3_repo/i586/pack2:package_multibuild_not_here/_log'
    assert_response :not_found
  end

  def test_read_sourceaccess_protected_logfile
    prepare_request_valid_user
    get '/build/SourceprotectedProject/repo/i586/pack/_log'
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'source_access_no_permission' })
    # retry with maintainer
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    get '/build/SourceprotectedProject/repo/i586/pack/_log'
    assert_response :success
  end

  def test_read_access_hidden_logfile
    prepare_request_valid_user
    get '/build/HiddenProject/nada/i586/pack/_log'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)
    # retry with maintainer
    login_adrian
    get '/build/HiddenProject/nada/i586/pack/_log'
    assert_response :success
  end

  def test_read_access_binarydownload_logfile
    prepare_request_valid_user
    # Download is not protecting binaries for real, but it disallows download via api
    get '/build/BinaryprotectedProject/nada/i586/bdpack/_log'
    assert_response :forbidden
    assert_match(/download_binary_no_permission/, @response.body)
    # retry with maintainer
    reset_auth
    prepare_request_with_user('binary_homer', 'buildservice')
    get '/build/BinaryprotectedProject/nada/i586/bdpack/_log'
    assert_response :success
  end

  def test_result
    get '/build/home:Iggy/_result'
    assert_response :success
    assert_xml_tag tag: 'resultlist', children: { count: 2 }

    get '/build/home:Iggy/_result?lastsuccess&pathproject=kde4&package=TestPack'
    assert_response :not_found
    assert_xml_tag(tag: 'status', attributes: { code: 'no_repositories_found' })
  end

  def test_result_of_failed_publish
    run_publisher
    get '/build/BrokenPublishing/_result'
    assert_response :success
    assert_xml_tag tag: 'result', attributes: { code: 'broken', state: 'broken', details: 'Testcase publish error' }
  end

  def test_read_access_hidden_result_prj
    get '/build/HiddenProject/_result'
    assert_response :not_found
    # retry with maintainer
    login_adrian
    get '/build/HiddenProject/_result'
    assert_response :success
    assert_xml_tag tag: 'resultlist'
    prepare_request_valid_user
  end

  def test_read_access_hidden_result_pkg
    get '/build/HiddenProject/_result?package=pack'
    assert_response :not_found
    # retry with maintainer
    reset_auth
    login_adrian
    get '/build/HiddenProject/_result?package=pack'
    assert_response :success
    assert_xml_tag tag: 'resultlist'
    prepare_request_valid_user
  end

  def test_binary_view
    get '/build/home:Iggy/10.2/i586/TestPack/file?view=fileinfo'
    assert_response :not_found
    assert_match(/file: No such file or directory/, @response.body)

    get '/build/home:Iggy/10.2/i586/TestPack/package-1.0-1.i586.rpm?view=fileinfo'
    assert_response :success
    # FIXME: validate xml content
  end

  def test_read_access_hidden_binary_view
    # 404 on invalid
    get '/build/HiddenProject/nada/i586/pack/package?view=fileinfo'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    get '/build/HiddenProject/nada/i586/pack/package-1.0-1.i586.rpm?view=fileinfo'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    # success on valid
    reset_auth
    login_adrian
    get '/build/HiddenProject/nada/i586/pack/package?view=fileinfo'
    assert_response :not_found
    assert_match(/No such file or directory/, @response.body)
    get '/build/HiddenProject/nada/i586/pack/package-1.0-1.i586.rpm?view=fileinfo'
    assert_response :success
    prepare_request_valid_user
  end

  def test_read_access_binarydownload_binary_view
    # 404 on invalid
    get '/build/BinaryprotectedProject/nada/i586/bdpack/package?view=fileinfo'
    assert_response :forbidden
    assert_match(/download_binary_no_permission/, @response.body)
    get '/build/BinaryprotectedProject/nada/i586/bdpack/package-1.0-1.i586.rpm?view=fileinfo'
    assert_response :forbidden
    assert_match(/download_binary_no_permission/, @response.body)
    # success on valid
    reset_auth
    prepare_request_with_user('binary_homer', 'buildservice')
    get '/build/BinaryprotectedProject/nada/i586/bdpack/package?view=fileinfo'
    assert_response :not_found
    assert_match(/No such file or directory/, @response.body)
    get '/build/BinaryprotectedProject/nada/i586/bdpack/package-1.0-1.i586.rpm?view=fileinfo'
    assert_response :success
    prepare_request_valid_user
  end

  def test_file
    get '/build/home:Iggy/10.2/i586/TestPack'
    assert_response :ok
    get '/build/home:Iggy/10.2/i586/TestPack/package-1.0-1.i586.rpm'
    assert_response :ok
    get '/build/home:Iggy/10.2/i586/TestPack/NOT_EXISTING'
    assert_response :not_found
    assert_match(/NOT_EXISTING: No such file or directory/, @response.body)
  end

  def test_read_access_hidden_file
    get '/build/HiddenProject/nada/i586/pack/'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    get '/build/HiddenProject/nada/i586/pack/package-1.0-1.i586.rpm'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    get '/build/HiddenProject/nada/i586/pack/NOT_EXISTING'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    # success on valid
    reset_auth
    login_adrian
    get '/build/HiddenProject/nada/i586/pack/'
    assert_response :success
    assert_match(/binarylist/, @response.body)
    get '/build/HiddenProject/nada/i586/pack/package-1.0-1.i586.rpm'
    assert_response :success
    get '/build/HiddenProject/nada/i586/pack/NOT_EXISTING'
    assert_match(/NOT_EXISTING: No such file or directory/, @response.body)
    prepare_request_valid_user
  end

  def test_project_index
    get '/build/home:Iggy'
    assert_response :success
    assert_xml_tag tag: 'directory', children: { count: 1 }

    put '/build/home:Iggy', params: { cmd: 'say_hallo' }
    assert_response :forbidden
    assert_match(/No permission to execute command on project/, @response.body)

    post '/build/home:Iggy', params: { cmd: 'say_hallo' }
    assert_response :bad_request
    assert_match(/unsupported POST command/, @response.body)

    login_Iggy
    post '/build/home:Iggy'
    assert_response :bad_request
    post '/build/home:Iggy?cmd=say_hallo'
    assert_response :bad_request
    post '/build/home:NotExisting?cmd=wipe'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)
    post '/build/home:Iggy?cmd=wipe&package=DoesNotExist'
    assert_response :not_found
    assert_match(/unknown package: DoesNotExist/, @response.body)

    post '/build/Apache?cmd=wipe'
    assert_response :forbidden
    assert_match(/No permission to execute command on project/, @response.body)
    post '/build/Apache?cmd=wipe&package=apache2'
    assert_response :forbidden
    assert_match(/No permission to execute command on package/, @response.body)

    post '/build/Apache?cmd=abortbuild'
    assert_response :forbidden
    assert_match(/No permission to execute command on project/, @response.body)
    post '/build/Apache?cmd=abortbuild&package=apache2'
    assert_response :forbidden
    assert_match(/No permission to execute command on package/, @response.body)

    login_fred
    post '/build/Apache?cmd=wipe'
    assert_response :success
    post '/build/Apache?cmd=wipe&package=apache2'
    assert_response :success

    post '/build/Apache?cmd=abortbuild'
    assert_response :success
    post '/build/Apache?cmd=abortbuild&package=apache2'
    assert_response :success
  end

  def test_read_access_hidden_project_index
    # Test if hidden projects appear for the right users
    # testing build_controller project_index
    # currently this test shows that there's an information leak.
    get '/build'
    assert_response :success
    assert_no_match(/entry name="HiddenProject"/, @response.body)
    # retry with maintainer
    login_adrian
    get '/build'
    assert_response :success
    assert_match(/entry name="HiddenProject"/, @response.body)
    prepare_request_valid_user

    # invalid
    get '/build/HiddenProject'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)

    put '/build/HiddenProject', params: { cmd: 'say_hallo' }
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)

    post '/build/HiddenProject', params: { cmd: 'say_hallo' }
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)

    post '/build/HiddenProject?cmd=wipe'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)

    post '/build/HiddenProject?cmd=wipe&package=TestPack'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)

    # valid
    reset_auth
    login_adrian
    get '/build/HiddenProject'
    assert_response :success
    assert_xml_tag tag: 'directory', children: { count: 1 }

    put '/build/HiddenProject', params: { cmd: 'say_hallo' }
    assert_response :forbidden
    assert_match(/No permission to execute command on project/, @response.body)

    post '/build/HiddenProject', params: { cmd: 'say_hallo' }
    assert_response :bad_request
    assert_match(/illegal_request/, @response.body)

    post '/build/HiddenProject?cmd=wipe&package=DoesNotExist'
    assert_response :not_found
    assert_match(/unknown package: DoesNotExist/, @response.body)

    post '/build/HiddenProject?cmd=wipe'
    assert_response :success
    post '/build/HiddenProject?cmd=wipe&package=pack'
    assert_response :success
  end

  def test_jobhistory
    get '/build/home:Iggy/10.2/i586/_jobhistory'
    assert_response :success
    get '/build/home:Iggy/10.2/i586/_jobhistory?package=TestPack'
    assert_response :success
  end

  def test_read_access_hidden_jobhistory
    get '/build/HiddenProject/nada/i586/_jobhistory'
    assert_response :not_found
    get '/build/HiddenProject/nada/i586/_jobhistory?package=pack'
    assert_response :not_found
    # retry with maintainer
    reset_auth
    login_adrian
    get '/build/HiddenProject/nada/i586/_jobhistory'
    assert_response :success
    get '/build/HiddenProject/nada/i586/_jobhistory?package=pack'
    assert_response :success
    prepare_request_valid_user
  end
end
