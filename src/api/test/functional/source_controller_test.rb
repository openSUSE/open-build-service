# rubocop:disable Metrics/ClassLength
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'source_controller'

class SourceControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    reset_auth
  end

  def test_get_projectlist_requires_login
    get '/source'
    assert_response :unauthorized
  end

  def test_get_projectlist
    login_tom
    get '/source'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'directory',
                   children: { only: { tag: 'entry' } }
  end

  def test_get_projectlist_with_hidden_project
    login_tom
    get '/source'
    assert_response :success
    assert_no_match(/entry name="HiddenProject"/, @response.body)

    # retry with maintainer
    login_adrian
    get '/source'
    assert_response :success
    assert_match(/entry name="HiddenProject"/, @response.body)
  end

  def test_get_projectlist_with_sourceaccess_protected_project
    login_tom
    get '/source'
    assert_response :success
    assert_match(/entry name="SourceprotectedProject"/, @response.body)
    # retry with maintainer
    login_adrian
    get '/source'
    assert_response :success
    assert_match(/entry name="SourceprotectedProject"/, @response.body)
  end

  def test_get_packagelist
    login_tom
    get '/source/kde4'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'directory',
                   children: { count: 2, only: { tag: 'entry' } }
  end

  # spec/controllers/source_controller_spec.rb
  def test_post_orderkiwirepos
    # urls with http protocol
    kiwi_config_http = <<~IMAGE
      <?xml version='1.0' encoding='UTF-8'?>
      <image name='openSUSE_JeOS' displayname='openSUSE_JeOS' schemaversion='5.2'>
        <repository type='rpm-md'>
          <source path='http://example.com/download/BaseDistro2.0/BaseDistro2_repo'/>
        </repository>
        <repository type='rpm-md'>
          <source path='http://example.com/download/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo'/>
        </repository>
      </image>
    IMAGE

    post '/source?cmd=orderkiwirepos', params: kiwi_config_http, headers: { 'Content-Type' => 'text/xml' }
    assert_response :ok
    converted_xml = Xmlhash.parse(response.body)
    first = converted_xml['repository'].first
    second = converted_xml['repository'].second
    assert_equal first['source']['path'], 'http://example.com/download/BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo'
    assert_equal second['source']['path'], 'http://example.com/download/BaseDistro2.0/BaseDistro2_repo'

    # urls with obs protocol
    kiwi_config_obs = <<~IMAGE
      <?xml version='1.0' encoding='UTF-8'?>
      <image name='openSUSE_JeOS' displayname='openSUSE_JeOS' schemaversion='5.2'>
        <repository type='rpm-md'>
          <source path='obs://BaseDistro2.0/BaseDistro2_repo'/>
        </repository>
        <repository type='rpm-md'>
          <source path='obs://BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo'/>
        </repository>
      </image>
    IMAGE

    post '/source?cmd=orderkiwirepos', params: kiwi_config_obs, headers: { 'Content-Type' => 'text/xml' }
    assert_response :ok
    converted_xml = Xmlhash.parse(response.body)
    first = converted_xml['repository'].first
    second = converted_xml['repository'].second
    assert_equal first['source']['path'], 'obs://BaseDistro2.0:LinkedUpdateProject/BaseDistro2LinkedUpdateProject_repo'
    assert_equal second['source']['path'], 'obs://BaseDistro2.0/BaseDistro2_repo'
  end

  # spec/controllers/source_controller_spec.rb
  def test_anonymous_access_for_global_commands
    post '/source?cmd=orderkiwirepos'
    # anonymous access allowed here, just forwarding the request to backend fails
    assert_response :bad_request

    post '/source?cmd=createmaintenanceincident'
    assert_response :unauthorized

    post '/source/kde4?cmd=branch'
    assert_response :unauthorized
  end

  def test_get_packagelist_with_hidden_project
    login_tom
    get '/source/HiddenProject'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)
    # retry with maintainer
    reset_auth
    login_adrian
    get '/source/HiddenProject'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'directory',
                   children: { count: 3, only: { tag: 'entry' } }
    assert_match(/entry name="pack"/, @response.body)
    assert_match(/entry name="target"/, @response.body)
  end

  def test_get_packagelist_with_sourceprotected_project
    login_tom
    get '/source/SourceprotectedProject'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'directory',
                   children: { count: 2 }
    assert_match(/entry name="target"/, @response.body)
    # retry with maintainer
    reset_auth
    login_adrian
    get '/source/SourceprotectedProject'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'directory',
                   children: { count: 2, only: { tag: 'entry' } }
    assert_match(/entry name="pack"/, @response.body)
    assert_match(/entry name="target"/, @response.body)
  end

  # non-existing project should return 404
  def test_get_illegal_project
    login_tom
    get '/source/kde2000/_meta'
    assert_response :not_found
  end

  # non-existing project-package should return 404
  def test_get_illegal_projectfile
    login_tom
    get '/source/kde4/kdelibs2000/_meta'
    assert_response :not_found
  end

  def test_use_illegal_encoded_parameters
    login_king
    put '/source/kde4/kdelibs/DUMMY?comment=working%20with%20Uml%C3%A4ut', params: 'WORKING'
    assert_response :success
    put '/source/kde4/kdelibs/DUMMY?comment=illegalchar%96%96asd', params: 'NOTWORKING'
    assert_response :bad_request
    delete '/source/kde4/kdelibs/DUMMY'
    assert_response :success
  end

  def test_get_project_meta
    login_tom
    get '/source/kde4/_meta'
    assert_response :success
    assert_xml_tag tag: 'project', attributes: { name: 'kde4' }
  end

  def test_get_project_meta_from_hidden_project
    login_tom
    get '/source/HiddenProject/_meta'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)
    # retry with maintainer
    reset_auth
    login_adrian
    get '/source/HiddenProject/_meta'
    assert_response :success
    assert_xml_tag tag: 'project', attributes: { name: 'HiddenProject' }
  end

  def test_get_project_meta_from_sourceaccess_protected_project
    login_tom
    get '/source/SourceprotectedProject/_meta'
    assert_response :success
    assert_xml_tag tag: 'project', attributes: { name: 'SourceprotectedProject' }
    # retry with maintainer
    reset_auth
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    get '/source/SourceprotectedProject/_meta'
    assert_response :success
    assert_xml_tag tag: 'project', attributes: { name: 'SourceprotectedProject' }
  end

  def test_get_package_filelist
    login_tom
    get '/source/kde4/kdelibs'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'directory',
                   children: { count: 1, only: { tag: 'entry', attributes: { name: 'my_patch.diff' } } }

    # now testing if also others can see it
    login_Iggy
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'directory',
                   children: { count: 1, only: { tag: 'entry', attributes: { name: 'my_patch.diff' } } }
  end

  def test_get_package_filelist_from_hidden_project
    login_tom
    get '/source/HiddenProject/pack'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    # retry with maintainer
    reset_auth
    login_adrian
    get '/source/HiddenProject/pack'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'directory',
                   children: { count: 2 }
  end

  def test_get_package_filelist_from_sourceaccess_protected_project
    login_tom
    get '/source/SourceprotectedProject/pack'
    assert_response :forbidden
    # retry with maintainer
    reset_auth
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    get '/source/SourceprotectedProject/pack'
    assert_response :success
    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'directory',
                   children: { count: 2 }
  end

  def test_get_package_meta
    login_tom
    get '/source/kde4/kdelibs/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { name: 'kdelibs' }

    # check history
    get '/source/kde4/kdelibs/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    assert_xml_tag(tag: 'user', content: 'king')
    assert_xml_tag(tag: 'comment', content: 'fixtures')
  end

  def test_put_minimal_package_meta
    login_tom
    # ensure that api and backend takes this minimal meta
    raw_put '/source/home:tom/MINIMAL/_meta', '<package name="MINIMAL"/>'
    assert_response :success

    # check created package in api and backend
    get '/source/home:tom/MINIMAL/_meta'
    assert_response :success
    get '/source/home:tom/MINIMAL'
    assert_response :success

    # cleanup
    delete '/source/home:tom/MINIMAL'
    assert_response :success
  end

  def test_get_package_meta_from_hidden_project
    login_tom
    get '/source/HiddenProject/pack/_meta'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    # retry with maintainer
    reset_auth
    login_adrian
    get '/source/HiddenProject/pack/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { name: 'pack', project: 'HiddenProject' }
  end

  def test_get_package_meta_from_sourceacces_protected_project
    # package meta is visible
    login_tom
    get '/source/SourceprotectedProject/pack/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { name: 'pack', project: 'SourceprotectedProject' }
    # retry with maintainer
    reset_auth
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    get '/source/SourceprotectedProject/pack/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { name: 'pack', project: 'SourceprotectedProject' }
  end

  def test_invalid_project_and_package_name
    login_king
    ['_invalid', '..'].each do |n|
      put url_for(controller: :source_project_meta, action: :update, project: n), params: "<project name='#{n}'> <title /> <description /> </project>"
      assert_response :bad_request
      assert_xml_tag tag: 'status', attributes: { code: 'invalid_project_name' }

      put "/source/kde4/#{n}/_meta", params: "<package project='kde4' name='#{n}'> <title /> <description /> </package>"
      assert_response :bad_request
      assert_xml_tag tag: 'status', attributes: { code: 'invalid_package_name' }

      post '/source/kde4/kdebase', params: { cmd: 'branch', target_package: n }
      assert_response :bad_request
      assert_xml_tag tag: 'status', attributes: { code: 'invalid_package_name' }

      post '/source/kde4/kdebase', params: { cmd: 'branch', target_project: n }
      assert_response :bad_request
      assert_xml_tag tag: 'status', attributes: { code: 'invalid_project_name' }

      post "/source/kde4/#{n}", params: { cmd: 'copy', opackage: 'kdebase', oproject: 'kde4' }
      assert_response :bad_request
      assert_xml_tag tag: 'status', attributes: { code: 'invalid_package_name' }

      post "/source/#{n}", params: { cmd: 'copy', oproject: 'kde4' }
      assert_response :bad_request
      assert_xml_tag tag: 'status', attributes: { code: 'invalid_project_name' }
    end
  end

  def test_branch_use_missingok_to_existing_package_fails
    login_king
    # package exists
    get '/source/BaseDistro2.0/pack2/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { project: 'BaseDistro2.0' }
    # ... via project link only
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2/_meta'
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { project: 'BaseDistro2.0' }

    # so branching fails
    post '/source/BaseDistro2.0/pack2', params: { cmd: :branch, missingok: 'true' }
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'not_missing' }
    post '/source/BaseDistro2.0/pack2', params: { cmd: :branch, missingok: 'true', maintenance: 1 }
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'not_missing' }
    # also indirect
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: :branch, missingok: 'true' }
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'not_missing' }
    # and from remote
    post '/source/UseRemoteInstance/pack2', params: { cmd: :branch, missingok: 'true' }
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'not_missing' }
  end

  def test_can_branch_package_under_two_names
    login_king
    post '/source/home:Iggy/TestPack', params: { cmd: 'branch', target_package: 'TestPack2' }
    assert_response :success
    # this is behaving strange as it's creating a TestPack3 pack, but returns a 400
    # as it tries to branch TestPack2 -> TestPack too and fails
    if @ENABLE_BROKEN_TEST
      post '/source/home:Iggy/TestPack', params: { cmd: 'branch', target_package: 'TestPack3' }
      assert_response :success
    end
    # cleanup
    delete '/source/home:king:branches:home:Iggy'
    assert_response :success
  end

  # project_meta does not require auth
  def test_invalid_user
    prepare_request_with_user('king123', 'buildservice')
    get '/source/kde4/_meta'
    assert_response :unauthorized
  end

  def test_valid_user
    login_tom
    get '/source/kde4/_meta'
    assert_response :success
  end

  def test_package_project_route_is_read_only
    login_tom
    get '/source/home:tom/_project/_meta'
    assert_response :success
    raw_put '/source/home:tom/_project/_meta', '<package name="_project"><title/><description/></package>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_parameter' }
  end

  def test_put_project_meta_with_invalid_permissions
    login_tom
    # The user is valid, but has weak permissions

    # Get meta file
    get '/source/kde4/_meta'
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = 'Changed description 1'
    doc = Nokogiri::XML(xml, &:strict).root
    d = doc.at_xpath('//description')
    d.content = new_desc

    # Write changed data back
    put url_for(controller: :source_project_meta, action: :update, project: 'kde4'), params: doc.to_xml
    assert_response :forbidden

    ### admin only tag
    # remote instance connection
    login_fred
    doc.add_child('<remoteurl>http://localhost:5352</remoteurl>')
    put url_for(controller: :source_project_meta, action: :update, project: 'kde4'), params: doc.to_xml
    assert_response :forbidden
    assert_match(/admin rights are required to change projects using remote resources/, @response.body)
    # DoD remote repository
    doc = Nokogiri::XML(xml, &:strict).root
    r = doc.add_child('<repository name="download_on_demand"/>')
    r.first.add_child('<download arch="i586" url="http://somewhere" repotype="rpmmd"/>')
    put url_for(controller: :source_project_meta, action: :update, project: 'kde4'), params: doc.to_xml
    assert_response :forbidden
    assert_match(/admin rights are required to change projects using remote resources/, @response.body)

    # invalid xml
    put url_for(controller: :source_project_meta, action: :update, project: 'NewProject'), params: '<asd/>'
    assert_response :bad_request
    assert_match(/validation error/, @response.body)

    # new project
    put url_for(controller: :source_project_meta, action: :update, project: 'NewProject'), params: "<project name='NewProject'><title>blub</title><description/></project>"
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'create_project_no_permission' }

    login_king
    put url_for(controller: :source_project_meta, action: :update, project: '_NewProject'), params: "<project name='_NewProject'><title>blub</title><description/></project>"
    assert_response :bad_request
    assert_match(/invalid project name/, @response.body)
  end

  def test_put_project_meta
    prj = 'kde4' # project
    resp1 = :success # expected response 1 & 2
    resp2 = :success # \/ expected assert
    aresp = { tag: 'status', attributes: { code: 'ok' } }
    match = true # value written matches 2nd read
    # admin
    login_king
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # maintainer
    login_fred
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # maintainer via group
    login_adrian
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)

    # check history
    get '/source/kde4/_project/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    assert_xml_tag(tag: 'user', content: 'adrian')
  end

  def test_create_subproject
    subprojectmeta = "<project name='kde4:subproject'><title></title><description/></project>"

    # nobody
    put url_for(controller: :source_project_meta, action: :update, project: 'kde4:subproject'), params: subprojectmeta
    assert_response :unauthorized
    assert_xml_tag tag: 'status', attributes: { code: 'authentication_required' }
    login_tom
    put url_for(controller: :source_project_meta, action: :update, project: 'kde4:subproject'), params: subprojectmeta
    assert_response :forbidden
    # admin
    login_king
    put url_for(controller: :source_project_meta, action: :update, project: 'kde4:subproject'), params: subprojectmeta
    assert_response :success
    delete '/source/kde4:subproject'
    assert_response :success
    # maintainer
    login_fred
    put url_for(controller: :source_project_meta, action: :update, project: 'kde4:subproject'), params: subprojectmeta
    assert_response :success
    delete '/source/kde4:subproject'
    assert_response :success
    # maintainer via group
    login_adrian
    put url_for(controller: :source_project_meta, action: :update, project: 'kde4:subproject'), params: subprojectmeta
    assert_response :success
    delete '/source/kde4:subproject'
    assert_response :success

    # create illegal project
    login_fred
    subprojectmeta = "<project name='kde4_subproject'><title></title><description/></project>"
    put url_for(controller: :source_project_meta, action: :update, project: 'kde4:subproject'), params: subprojectmeta
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'project_name_mismatch' }

    # and it does not exist indeed ...
    get '/source/kde4_subproject'
    assert_response :not_found
    get '/source/kde4:subproject'
    assert_response :not_found
  end

  def test_put_project_meta_hidden_project
    prj = 'HiddenProject'
    # uninvolved user
    resp1 = 404
    resp2 = nil
    aresp = nil
    match = nil
    login_tom
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # admin
    resp1 = :success
    resp2 = :success
    aresp = { tag: 'status', attributes: { code: 'ok' } }
    match = true
    login_king
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # maintainer
    prepare_request_with_user('hidden_homer', 'buildservice')
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # FIXME: maintainer via group
  end

  def test_put_project_meta_sourceaccess_protected_project
    prj = 'SourceprotectedProject'
    # uninvolved user - can't change meta
    resp1 = :success
    resp2 = 403
    aresp = { tag: 'status', attributes: { code: 'change_project_no_permission' } }
    match = nil
    login_tom
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # same with set_flag command ?
    post '/source/SourceprotectedProject?cmd=set_flag&flag=sourceaccess&status=enable'
    assert_response :forbidden
    assert_match(/no permission to execute command/, @response.body)
    # admin
    resp1 = :success
    resp2 = :success
    aresp = { tag: 'status', attributes: { code: 'ok' } }
    match = true
    login_king
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
    # maintainer
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    do_change_project_meta_test(prj, resp1, resp2, aresp, match)
  end

  def test_create_and_remove_release_targets
    rel_target_meta = "<project name='TEMPORARY:rel_target'><title></title><description/>
                      <repository name='rel_target1'>
                        <path project='BaseDistro' repository='BaseDistro_repo'/>
                        <arch>x86_64</arch>
                      </repository>
                      <repository name='rel_target2'>
                        <path project='BaseDistro' repository='BaseDistro_repo'/>
                        <arch>x86_64</arch>
                      </repository>
                   </project>"
    build_meta = "<project name='TEMPORARY:build'><title></title><description/>
                      <repository name='repo1'>
                        <releasetarget project='TEMPORARY:rel_target' repository='rel_target1'/>
                        <path project='BaseDistro' repository='BaseDistro_repo'/>
                        <arch>x86_64</arch>
                      </repository>
                      <repository name='repo2'>
                        <releasetarget project='TEMPORARY:rel_target' repository='rel_target2'/>
                        <path project='BaseDistro' repository='BaseDistro_repo'/>
                        <arch>x86_64</arch>
                      </repository>
                   </project>"

    # create them
    login_king
    put url_for(controller: :source_project_meta, action: :update, project: 'TEMPORARY:rel_target'), params: rel_target_meta
    assert_response :success
    get '/source/TEMPORARY:rel_target/_meta'
    assert_response :success
    put url_for(controller: :source_project_meta, action: :update, project: 'TEMPORARY:build'), params: build_meta
    assert_response :success
    get '/source/TEMPORARY:build/_meta'
    assert_response :success
    assert_xml_tag parent: { tag: 'repository', attributes: { name: 'repo1' } },
                   tag: 'releasetarget', attributes: { project: 'TEMPORARY:rel_target', repository: 'rel_target1' }
    assert_xml_tag parent: { tag: 'repository', attributes: { name: 'repo2' } },
                   tag: 'releasetarget', attributes: { project: 'TEMPORARY:rel_target', repository: 'rel_target2' }

    # delete one repository where a release target defintion points to
    rel_target_meta = "<project name='TEMPORARY:rel_target'><title></title><description/>
                      <repository name='rel_target2'>
                        <path project='BaseDistro' repository='BaseDistro_repo'/>
                        <arch>x86_64</arch>
                      </repository>
                   </project>"
    put '/source/TEMPORARY:rel_target/_meta', params: rel_target_meta
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'repo_dependency' })
    assert_match(/following target repositories depend on this project:/, @response.body)
    put '/source/TEMPORARY:rel_target/_meta?force=1', params: rel_target_meta
    assert_response :success
    get '/source/TEMPORARY:rel_target/_meta'
    assert_response :success
    get '/source/TEMPORARY:build/_meta'
    assert_response :success
    assert_xml_tag parent: { tag: 'repository', attributes: { name: 'repo1' } },
                   tag: 'releasetarget', attributes: { project: 'deleted', repository: 'deleted' }
    assert_xml_tag parent: { tag: 'repository', attributes: { name: 'repo2' } },
                   tag: 'releasetarget', attributes: { project: 'TEMPORARY:rel_target', repository: 'rel_target2' }

    # delete entire project including release target
    delete '/source/TEMPORARY:rel_target'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'repo_dependency' })
    delete '/source/TEMPORARY:rel_target?force=1'
    assert_response :success
    get '/source/TEMPORARY:rel_target/_meta'
    assert_response :not_found
    get '/source/TEMPORARY:build/_meta'
    assert_response :success
    assert_xml_tag parent: { tag: 'repository', attributes: { name: 'repo1' } },
                   tag: 'releasetarget', attributes: { project: 'deleted', repository: 'deleted' }
    assert_xml_tag parent: { tag: 'repository', attributes: { name: 'repo2' } },
                   tag: 'releasetarget', attributes: { project: 'deleted', repository: 'deleted' }

    # cleanup
    delete '/source/TEMPORARY:build'
    assert_response :success
  end

  def do_change_project_meta_test(project, response1, response2, tag2, doesmatch)
    # Get meta file
    get url_for(controller: :source_project_meta, action: :show, project: project)
    assert_response response1
    unless response2 && tag2
      # dummy write to check blocking
      put url_for(controller: :source_project_meta, action: :update, project: project), params: "<project name=\"#{project}\"><title></title><description></description></project>"
      assert_response :forbidden # 4
      #      assert_match(/unknown_project/, @response.body)
      assert_match(/create_project_no_permission/, @response.body)
      return
    end

    # Change description
    xml = @response.body
    new_desc = 'Changed description 2'
    doc = REXML::Document.new(xml)
    d = doc.elements['//description']
    d.text = new_desc

    # Write changed data back
    put url_for(controller: :source_project_meta, action: :update, project: project), params: doc.to_s
    assert_response response2
    assert_xml_tag(tag2)

    # Get data again and check that it is the changed data
    get url_for(controller: :source_project_meta, action: :show, project: project)
    assert_response :success
    assert_equal new_desc, Xmlhash.parse(@response.body)['description'] if doesmatch
  end

  private :do_change_project_meta_test

  def test_create_and_delete_project
    prepare_request_with_user('king', 'sunflower')
    # Get meta file
    get url_for(controller: :source_project_meta, action: :show, project: 'kde4')
    assert_response :success

    xml = @response.body
    doc = REXML::Document.new(xml)
    # change name to kde5:
    d = doc.elements['/project']
    d.delete_attribute('name')
    d.add_attribute('name', 'kde5')
    put url_for(controller: :source_project_meta, action: :update, project: 'kde5'), params: doc.to_s
    assert_response(:success, '--> king was not allowed to create a project')
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })

    # Get data again and check that the maintainer was added
    get url_for(controller: :source_project_meta, action: :show, project: 'kde5')
    assert_response :success
    assert_select 'project[name=kde5]'
    assert_select 'person[userid=king][role=maintainer]', {}, 'Creator was not added as project maintainer'

    prepare_request_with_user('maintenance_coord', 'buildservice')
    delete '/source/kde5'
    assert_response :forbidden
    login_fred
    delete '/source/kde5'
    assert_response :success
  end

  def test_put_invalid_project_meta
    login_fred

    # Get meta file
    get url_for(controller: :source_project_meta, action: :show, project: 'kde4')
    assert_response :success

    xml = @response.body
    olddoc = REXML::Document.new(xml)
    doc = REXML::Document.new(xml)
    # Write corrupt data back
    put url_for(controller: :source_project_meta, action: :update, project: 'kde4'), params: doc.to_s + '</xml>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'validation_failed' }

    login_king
    # write to illegal location:
    put url_for(controller: :source_project_meta, action: :update, project: '$hash'), params: doc.to_s
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_project_name' }

    # must not create a project with different pathname and name in _meta.xml:
    put url_for(controller: :source_project_meta, action: :update, project: 'kde5'), params: doc.to_s
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'project_name_mismatch' }
    # TODO: referenced repository names must exist

    # verify data is unchanged:
    get url_for(controller: :source_project_meta, action: :show, project: 'kde4')
    assert_response :success
    assert_equal(olddoc.to_s, REXML::Document.new(@response.body).to_s)
  end

  def test_remove_myself_from_home_project_and_readd
    login_fred

    # Get meta file
    get url_for(controller: :source_project_meta, action: :show, project: 'home:fred')
    assert_response :success
    xml = @response.body
    doc = REXML::Document.new(xml)

    # drop myself (fred)
    doc.elements['/project'].delete_element 'person'
    put url_for(controller: :source_project_meta, action: :update, project: 'home:fred'), params: doc.to_s
    assert_response :success

    # no person inside anymore
    get url_for(controller: :source_project_meta, action: :show, project: 'home:fred')
    assert_response :success
    assert_no_xml_tag tag: 'person'

    # but we are still allowed to modify our home meta, for example to re-add ourself
    put url_for(controller: :source_project_meta, action: :update, project: 'home:fred'), params: xml
    assert_response :success
  end

  def test_lock_project
    login_Iggy
    put '/source/home:Iggy/TestLinkPack/_meta', params: "<package project='home:Iggy' name='TestLinkPack'> <title/> <description/> </package>"
    assert_response :success
    put '/source/home:Iggy/TestLinkPack/_link', params: "<link package='TestPack' />"
    assert_response :success

    # lock project
    get '/source/home:Iggy/_meta'
    assert_response :success
    doc = REXML::Document.new(@response.body)
    doc.elements['/project'].add_element 'lock'
    doc.elements['/project/lock'].add_element 'enable'
    put '/source/home:Iggy/_meta', params: doc.to_s
    assert_response :success
    get '/source/home:Iggy/_meta'
    assert_response :success
    assert_xml_tag parent: { tag: 'project' }, tag: 'lock'
    assert_xml_tag parent: { tag: 'lock' }, tag: 'enable'

    # modifications are not allowed anymore
    delete '/source/home:Iggy'
    assert_response :forbidden
    delete '/source/home:Iggy/TestLinkPack'
    assert_response :forbidden
    doc.elements['/project/description'].text = 'new text'
    put '/source/home:Iggy/_meta', params: doc.to_s
    assert_response :forbidden
    put '/source/home:Iggy/TestLinkPack/_link', params: ''
    assert_response :forbidden
    post '/build/home:Iggy?cmd=wipe'
    assert_response :forbidden

    # check branching from a locked project
    post '/source/home:Iggy/TestLinkPack', params: { cmd: 'branch' }
    assert_response :success
    get '/source/home:Iggy:branches:home:Iggy/_meta'
    assert_response :success
    assert_no_xml_tag tag: 'lock'

    # unlock will fail on unlocked project
    post '/source/home:Iggy:branches:home:Iggy', params: { cmd: 'unlock', comment: 'dummy' }
    assert_response :bad_request
    assert_select 'status', code: 'not_locked'
    # lock via command
    post '/source/home:Iggy:branches:home:Iggy?cmd=lock'
    assert_response :success
    get '/source/home:Iggy:branches:home:Iggy/_meta'
    assert_response :success
    assert_select 'project' do
      assert_select 'lock' do
        assert_select 'enable'
      end
    end

    # try to unlock without comment
    post '/source/home:Iggy', params: { cmd: 'unlock' }
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'missing_parameter' }

    # unlock does not work via meta data anymore
    doc.elements['/project/lock'].delete_element 'enable'
    doc.elements['/project/lock'].add_element 'disable'
    put '/source/home:Iggy/_meta', params: doc.to_s
    assert_response :forbidden

    # check unlock command
    login_adrian
    post '/source/home:Iggy', params: { cmd: 'unlock', comment: 'cleanup' }
    assert_response :forbidden
    login_Iggy
    post '/source/home:Iggy', params: { cmd: 'unlock', comment: 'cleanup' }
    assert_response :success
    post '/source/home:Iggy:branches:home:Iggy', params: { cmd: 'unlock', comment: 'cleanup' }
    assert_response :success

    # cleanup works now again
    delete '/source/home:Iggy/TestLinkPack'
    assert_response :success
    delete '/source/home:Iggy:branches:home:Iggy'
    assert_response :success
  end

  def test_check_lock_and_unlock_of_empty_project
    login_Iggy
    put '/source/home:Iggy:TEST/_meta', params: "<project name='home:Iggy:TEST'> <title/> <description/> </project>"
    assert_response :success

    # lock command
    post '/source/home:Iggy:TEST?cmd=lock'
    assert_response :success
    get '/source/home:Iggy:TEST/_meta'
    assert_response :success
    assert_xml_tag tag: 'lock'

    # unlock command
    post '/source/home:Iggy:TEST?cmd=unlock&comment=doit'
    assert_response :success
    get '/source/home:Iggy:TEST/_meta'
    assert_response :success
    assert_no_xml_tag tag: 'lock'

    delete '/source/home:Iggy:TEST'
    assert_response :success
  end

  def test_lock_package
    login_Iggy
    put '/source/home:Iggy/TestLinkPack/_meta', params: "<package project='home:Iggy' name='TestLinkPack'> <title/> <description/> </package>"
    assert_response :success

    # lock package
    get '/source/home:Iggy/TestLinkPack/_meta'
    assert_response :success
    doc = REXML::Document.new(@response.body)
    doc.elements['/package'].add_element 'lock'
    doc.elements['/package/lock'].add_element 'enable'
    put '/source/home:Iggy/TestLinkPack/_meta', params: doc.to_s
    assert_response :success
    get '/source/home:Iggy/TestLinkPack/_meta'
    assert_response :success
    assert_xml_tag parent: { tag: 'package' }, tag: 'lock'
    assert_xml_tag parent: { tag: 'lock' }, tag: 'enable'

    # modifications are not allowed anymore
    delete '/source/home:Iggy/TestLinkPack'
    assert_response :forbidden
    doc.elements['/package/description'].text = 'new text'
    put '/source/home:Iggy/TestLinkPack/_meta', params: doc.to_s
    assert_response :forbidden
    put '/source/home:Iggy/TestLinkPack/_link', params: ''
    assert_response :forbidden

    # make package read-writable is not working via meta
    doc.elements['/package/lock'].delete_element 'enable'
    doc.elements['/package/lock'].add_element 'disable'
    put '/source/home:Iggy/TestLinkPack/_meta', params: doc.to_s
    assert_response :forbidden

    # try to unlock without comment
    post '/source/home:Iggy/TestLinkPack', params: { cmd: 'unlock' }
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'missing_parameter' }
    # without permissions
    login_adrian
    post '/source/home:Iggy/TestLinkPack', params: { cmd: 'unlock', comment: 'BlahFasel' }
    assert_response :forbidden
    # do for real and cleanup
    login_Iggy
    post '/source/home:Iggy/TestLinkPack', params: { cmd: 'unlock', comment: 'BlahFasel' }
    assert_response :success
    delete '/source/home:Iggy/TestLinkPack'
    assert_response :success
  end

  def test_put_package_meta_with_invalid_permissions
    login_tom
    # The user is valid, but has weak permissions
    get url_for(controller: :source_package_meta, action: :show, project: 'kde4', package: 'kdelibs')
    assert_response :success

    # Change description
    xml = @response.body
    new_desc = 'Changed description 4'
    olddoc = REXML::Document.new(xml)
    doc = REXML::Document.new(xml)
    d = doc.elements['//description']
    d.text = new_desc

    # Write changed data back
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'kdelibs'), params: doc.to_s
    assert_response :forbidden

    # verify data is unchanged:
    get url_for(controller: :source_package_meta, action: :show, project: 'kde4', package: 'kdelibs')
    assert_response :success
    assert_equal(olddoc.to_s, REXML::Document.new(@response.body).to_s)

    # try to trick api via non matching xml attributes
    doc.root.attributes['project'] = 'kde4'
    put url_for(controller: :source_package_meta, action: :update, project: 'home:tom', package: 'kdelibs'), params: doc.to_s
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'project_name_mismatch' })
    doc.root.attributes['project'] = nil
    doc.root.attributes['name'] = 'none'
    put url_for(controller: :source_package_meta, action: :update, project: 'home:tom', package: 'kdelibs'), params: doc.to_s
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'package_name_mismatch' })
  end

  def test_put_package_meta_to_hidden_pkg_invalid_permissions
    login_tom
    # The user is valid, but has weak permissions
    get url_for(controller: :source_package_meta, action: :show, project: 'HiddenProject', package: 'pack')
    assert_response :not_found

    # Write changed data back
    put url_for(controller: :source_package_meta, action: :update, project: 'HiddenProject', package: 'pack'), params: '<package name="pack"><title></title><description></description></package>'
    assert_response :not_found
  end

  def do_change_package_meta_test(project, package, response1, response2, tag2, match)
    # Get meta file
    get url_for(controller: :source_package_meta, action: :show, project: project, package: package)
    assert_response response1

    unless response2 && tag2
      # dummy write to check blocking
      put url_for(controller: :source_package_meta, action: :update, project: project, package: package), params: '<package><title></title><description></description></package>'
      assert_response :not_found
      #      assert_match(/unknown_package/, @response.body)
      assert_match(/unknown_project/, @response.body)
      return
    end
    # Change description
    xml = @response.body
    new_desc = 'Changed description 3'
    doc = REXML::Document.new(xml)
    d = doc.elements['//description']
    d.text = new_desc

    # Write changed data back
    put url_for(controller: :source_package_meta, action: :update, project: project, package: package), params: doc.to_s
    assert_response response2 # (:success, "--> Was not able to update kdelibs _meta")
    assert_xml_tag tag2 # ( :tag => "status", :attributes => { :code => "ok"} )

    # Get data again and check that it is the changed data
    get url_for(controller: :source_package_meta, action: :show, project: project, package: package)
    newdoc = REXML::Document.new(@response.body)
    d = newdoc.elements['//description']
    # ignore updated change
    newdoc.root.attributes['updated'] = doc.root.attributes['updated']
    assert_equal new_desc, d.text if match
    assert_equal doc.to_s, newdoc.to_s if match
  end

  private :do_change_package_meta_test

  # admins, project-maintainer and package maintainer can edit package data
  def test_put_package_meta
    prj = 'kde4'
    pkg = 'kdelibs'
    resp1 = :success
    resp2 = :success
    aresp = { tag: 'status', attributes: { code: 'ok' } }
    match = true
    # admin
    login_king
    do_change_package_meta_test(prj, pkg, resp1, resp2, aresp, match)
    # maintainer via user
    login_fred
    do_change_package_meta_test(prj, pkg, resp1, resp2, aresp, match)
    prepare_request_with_user('fredlibs', 'buildservice')
    do_change_package_meta_test(prj, pkg, resp1, resp2, aresp, match)
    # maintainer via group
    login_adrian
    do_change_package_meta_test(prj, pkg, resp1, resp2, aresp, match)

    # check history
    get '/source/kde4/kdelibs/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    assert_xml_tag(tag: 'user', content: 'adrian')
  end

  def test_put_package_meta_hidden_package
    prj = 'HiddenProject'
    pkg = 'pack'
    resp1 = 404
    resp2 = nil
    aresp = nil
    match = false
    # uninvolved user
    login_fred
    do_change_package_meta_test(prj, pkg, resp1, resp2, aresp, match)
    # admin
    resp1 = :success
    resp2 = :success
    aresp = { tag: 'status', attributes: { code: 'ok' } }
    match = true
    login_king
    do_change_package_meta_test(prj, pkg, resp1, resp2, aresp, match)
    # maintainer
    prepare_request_with_user('hidden_homer', 'buildservice')
    do_change_package_meta_test(prj, pkg, resp1, resp2, aresp, match)
  end

  def test_put_package_meta_sourceaccess_protected_package
    prj = 'SourceprotectedProject'
    pkg = 'pack'
    resp1 = :success
    resp2 = 403
    aresp = { tag: 'status', attributes: { code: 'update_project_not_authorized' } }
    match = nil
    # uninvolved user
    login_fred
    do_change_package_meta_test(prj, pkg, resp1, resp2, aresp, match)
    # admin
    resp1 = :success
    resp2 = :success
    aresp = { tag: 'status', attributes: { code: 'ok' } }
    match = true
    login_king
    do_change_package_meta_test(prj, pkg, resp1, resp2, aresp, match)
    # maintainer
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    do_change_package_meta_test(prj, pkg, resp1, resp2, aresp, match)
  end

  def test_create_package_meta
    # user without any special roles
    login_fred
    get url_for(controller: :source_package_meta, action: :show, project: 'kde4', package: 'kdelibs')
    assert_response :success
    # change name to kdelibs2
    xml = @response.body
    doc = REXML::Document.new(xml)
    d = doc.elements['/package']
    d.delete_attribute('name')
    d.add_attribute('name', 'kdelibs2')
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'kdelibs2'), params: doc.to_s
    assert_response :success
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })
    # do not allow to create it with invalid name
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'kdelibs3'), params: doc.to_s
    assert_response :bad_request

    # Get data again and check that the maintainer was added
    get url_for(controller: :source_package_meta, action: :show, project: 'kde4', package: 'kdelibs2')
    assert_response :success
    newdoc = REXML::Document.new(@response.body)
    d = newdoc.elements['/package']
    assert_equal(d.attribute('name').value, 'kdelibs2', 'Project name was not set to kdelibs2')

    # check for lacking permission to create a package
    login_tom
    d.delete_attribute('name')
    d.add_attribute('name', 'kdelibs3')
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'kdelibs3'), params: newdoc.to_s
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'update_project_not_authorized' })

    # cleanup
    login_king
    delete '/source/kde4/kdelibs2'
    assert_response :success
  end

  def test_captial_letter_change
    login_tom
    put '/source/home:tom:projectA/_meta', params: "<project name='home:tom:projectA'> <title/> <description/> <repository name='repoA'/> </project>"
    assert_response :success
    put '/source/home:tom:projectB/_meta', params: "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='home:tom:projectA' repository='repoA' /> </repository> </project>"
    assert_response :success
    get '/source/home:tom:projectB/_meta'
    assert_response :success
    assert_xml_tag tag: 'path', attributes: { project: 'home:tom:projectA' }
    assert_no_xml_tag tag: 'path', attributes: { project: 'home:tom:projecta' }

    # write again with a capital letter change
    put '/source/home:tom:projectB/_meta', params: "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='home:tom:projecta' repository='repoA' /> </repository> </project>"
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'repository_access_failure' }
    get '/source/home:tom:projectB/_meta'
    assert_response :success
    assert_xml_tag tag: 'path', attributes: { project: 'home:tom:projectA' }
    assert_no_xml_tag tag: 'path', attributes: { project: 'home:tom:projecta' }

    # change back using remote project
    put '/source/home:tom:projectB/_meta',
        params: "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='RemoteInstance:home:tom:projectA' repository='repoA' /> </repository> </project>"
    assert_response :success
    get '/source/home:tom:projectB/_meta'
    assert_response :success
    assert_xml_tag tag: 'path', attributes: { project: 'RemoteInstance:home:tom:projectA' }
    assert_no_xml_tag tag: 'path', attributes: { project: 'RemoteInstance:home:tom:projecta' }

    if @ENABLE_BROKEN_TEST
      # FIXME: the case insensitive database select is not okay.
      # and switch letter again
      put '/source/home:tom:projectB/_meta',
          params: "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='RemoteInstance:home:tom:projecta' repository='repoA' /> </repository> </project>"
      assert_response :not_found
      assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
      get '/source/home:tom:projectB/_meta'
      assert_response :success
      assert_xml_tag tag: 'path', attributes: { project: 'RemoteInstance:home:tom:projectA' }
      assert_no_xml_tag tag: 'path', attributes: { project: 'RemoteInstance:home:tom:projecta' }
    end

    # cleanup
    delete '/source/home:tom:projectB'
    assert_response :success
    delete '/source/home:tom:projectA'
    assert_response :success
  end

  def test_repository_dependencies
    login_tom
    put '/source/home:tom:projectA/_meta', params: "<project name='home:tom:projectA'> <title/> <description/> <repository name='repoA'/> </project>"
    assert_response :success
    put '/source/home:tom:projectB/_meta', params: "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='home:tom:projectA' repository='repoA' /> </repository> </project>"
    assert_response :success
    put '/source/home:tom:projectC/_meta', params: "<project name='home:tom:projectC'> <title/> <description/> <repository name='repoC'> <path project='home:tom:projectB' repository='repoB' /> </repository> </project>"
    assert_response :success
    put '/source/home:tom:projectD/_meta', params: "<project name='home:tom:projectD'> <title/> <description/> <repository name='repoD'>  " \
                                                   "<path project='home:tom:projectA' repository='repoA' /> " \
                                                   "<path project='home:tom:projectB' repository='repoB' /> " \
                                                   "<path project='home:tom:projectC' repository='repoC' />" \
                                                   '</repository> </project>'
    assert_response :success
    # delete a repo
    put '/source/home:tom:projectA/_meta', params: "<project name='home:tom:projectA'> <title/> <description/> </project>"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'repo_dependency' })
    delete '/source/home:tom:projectA'
    assert_response :bad_request
    put '/source/home:tom:projectA/_meta?force=1', params: "<project name='home:tom:projectA'> <title/> <description/> </project>"
    assert_response :success
    get '/source/home:tom:projectB/_meta'
    assert_response :success
    assert_xml_tag tag: 'path', attributes: { project: 'deleted', repository: 'deleted' }
    get '/source/home:tom:projectC/_meta'
    assert_response :success
    assert_xml_tag tag: 'path', attributes: { project: 'home:tom:projectB', repository: 'repoB' } # unmodified

    # delete another repo
    put '/source/home:tom:projectB/_meta?force=1', params: "<project name='home:tom:projectB'> <title/> <description/> </project>"
    assert_response :success
    get '/source/home:tom:projectD/_meta'
    assert_response :success
    assert_xml_tag tag: 'path', attributes: { project: 'deleted', repository: 'deleted' }
    assert_xml_tag tag: 'path', attributes: { project: 'home:tom:projectC', repository: 'repoC' } # unmodified

    # cleanup
    delete '/source/home:tom:projectA'
    assert_response :success
    delete '/source/home:tom:projectB'
    assert_response :success
    delete '/source/home:tom:projectC'
    assert_response :bad_request # projectD is still using it
    delete '/source/home:tom:projectD'
    assert_response :success
    delete '/source/home:tom:projectC'
    assert_response :success
  end

  def test_full_remove_repository_dependencies
    login_tom
    put '/source/home:tom:projectA/_meta', params: "<project name='home:tom:projectA'> <title/> <description/> <repository name='repoA'/> </project>"
    assert_response :success
    put '/source/home:tom:projectB/_meta', params: "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='home:tom:projectA' repository='repoA' /> </repository> </project>"
    assert_response :success
    put '/source/home:tom:projectC/_meta', params: "<project name='home:tom:projectC'> <title/> <description/> <repository name='repoC'> <path project='home:tom:projectB' repository='repoB' /> </repository> </project>"
    assert_response :success
    # delete a repo
    put '/source/home:tom:projectA/_meta', params: "<project name='home:tom:projectA'> <title/> <description/> </project>"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'repo_dependency' })
    delete '/source/home:tom:projectA'
    assert_response :bad_request
    put '/source/home:tom:projectA/_meta?force=1&remove_linking_repositories=1', params: "<project name='home:tom:projectA'> <title/> <description/> </project>"
    assert_response :success
    get '/source/home:tom:projectB/_meta'
    assert_response :success
    assert_no_xml_tag tag: 'path'
    get '/source/home:tom:projectC/_meta'
    assert_response :success
    assert_no_xml_tag tag: 'path'

    # cleanup
    delete '/source/home:tom:projectA'
    assert_response :success
    delete '/source/home:tom:projectB'
    assert_response :success
    delete '/source/home:tom:projectC'
    assert_response :success
  end

  def test_fail_correctly_with_broken_repo_config
    login_tom
    # double definition of i586 architecture
    put '/source/home:tom:projectA/_meta', params: "<project name='home:tom:projectA'> <title/> <description/> <repository name='repoA'> <arch>i586</arch> <arch>i586</arch> </repository> </project>"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'project_save_error' })
    assert_match(/double use of architecture: 'i586'/, @response.body)
  end

  def test_delete_project_with_repository_dependencies
    login_tom
    put '/source/home:tom:projectA/_meta', params: "<project name='home:tom:projectA'> <title/> <description/> <repository name='repoA'> <arch>i586</arch> </repository> </project>"
    assert_response :success
    put '/source/home:tom:projectB/_meta',
        params: "<project name='home:tom:projectB'> <title/> <description/> <repository name='repoB'> <path project='home:tom:projectA' repository='repoA' /> <arch>i586</arch> </repository> </project>"
    assert_response :success
    # delete the project including the repository
    delete '/source/home:tom:projectA'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'repo_dependency' })
    delete '/source/home:tom:projectA?force=1'
    assert_response :success
    get '/source/home:tom:projectB/_meta'
    assert_response :success
    assert_xml_tag tag: 'path', attributes: { project: 'deleted', repository: 'deleted' }
    put '/source/home:tom:projectB/_meta', params: "<project name='home:tom:projectB'> <title/> <description/> </project>"
    assert_response :success

    # cleanup
    delete '/source/home:tom:projectB'
    assert_response :success
  end

  def test_delete_project_with_local_devel_packages
    login_tom
    put '/source/home:tom:project/_meta', params: "<project name='home:tom:project'> <title/> <description/> <repository name='repoA'> <arch>i586</arch> </repository> </project>"
    assert_response :success
    put '/source/home:tom:project/A/_meta', params: "<package name='A' project='home:tom:project'> <title/> <description/></package>"
    assert_response :success
    put '/source/home:tom:project/B/_meta', params: "<package name='B' project='home:tom:project'> <title/> <description/> <devel package='A'/> </package>"
    assert_response :success
    put '/source/home:tom:project/C/_meta', params: "<package name='C' project='home:tom:project'> <title/> <description/> <devel package='B'/> </package>"
    assert_response :success
    login_king
    put '/source/BaseDistro/pack2/_meta', params: "<package name='pack2' project='BaseDistro'> <title/> <description/> <devel package='A' project='home:tom:project'/> </package>"
    assert_response :success
    login_tom
    # delete a package which is used as devel package
    get '/source/home:tom:project/B/_meta'
    assert_response :success
    assert_xml_tag tag: 'devel'
    delete '/source/home:tom:project/A'
    assert_response :bad_request
    assert_select 'status', code: 'delete_error' do
      assert_select 'summary', 'Package is used by following packages as devel package: BaseDistro/pack2, home:tom:project/B'
    end
    delete '/source/home:tom:project/A?force=1'
    assert_response :success
    get '/source/home:tom:project/A/_meta'
    assert_response :not_found
    get '/source/home:tom:project/B/_meta'
    assert_response :success
    assert_no_xml_tag tag: 'devel'
    # delete the project including the packages
    delete '/source/home:tom:project'
    assert_response :success
  end

  def test_devel_project_cycle
    login_tom
    put '/source/home:tom:A/_meta', params: "<project name='home:tom:A'> <title/> <description/> </project>"
    assert_response :success
    put '/source/home:tom:B/_meta', params: "<project name='home:tom:B'> <title/> <description/> <devel project='home:tom:A'/> </project>"
    assert_response :success
    get '/source/home:tom:B/_meta'
    assert_response :success
    assert_xml_tag tag: 'devel', attributes: { project: 'home:tom:A' }
    put '/source/home:tom:C/_meta', params: "<project name='home:tom:C'> <title/> <description/> <devel project='home:tom:B'/> </project>"
    assert_response :success
    # no self reference
    put '/source/home:tom:A/_meta', params: "<project name='home:tom:A'> <title/> <description/> <devel project='home:tom:A'/> </project>"
    assert_response :bad_request
    # create a cycle via new package
    put '/source/home:tom:A/_meta', params: "<project name='home:tom:A'> <title/> <description/> <devel project='home:tom:C'/> </project>"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'project_cycle' })

    delete '/source/home:tom:C'
    assert_response :success
    delete '/source/home:tom:B'
    assert_response :success
    delete '/source/home:tom:A'
    assert_response :success
  end

  def test_devel_package_cycle
    login_tom
    put '/source/home:tom/packageA/_meta', params: "<package project='home:tom' name='packageA'> <title/> <description/> </package>"
    assert_response :success
    put '/source/home:tom/packageB/_meta', params: "<package project='home:tom' name='packageB'> <title/> <description/> <devel package='packageA' /> </package>"
    assert_response :success
    put '/source/home:tom/packageC/_meta', params: "<package project='home:tom' name='packageC'> <title/> <description/> <devel package='packageB' /> </package>"
    assert_response :success
    # no self reference
    put '/source/home:tom/packageA/_meta', params: "<package project='home:tom' name='packageA'> <title/> <description/> <devel package='packageA' /> </package>"
    assert_response :bad_request
    # create a cycle via new package
    put '/source/home:tom/packageB/_meta', params: "<package project='home:tom' name='packageB'> <title/> <description/> <devel package='packageC' /> </package>"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'cycle_error' })
    # create a cycle via existing package
    put '/source/home:tom/packageA/_meta', params: "<package project='home:tom' name='packageA'> <title/> <description/> <devel package='packageB' /> </package>"
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'cycle_error' })

    # cleanup
    delete '/source/home:tom/packageC'
    assert_response :success
    delete '/source/home:tom/packageB'
    assert_response :success
    delete '/source/home:tom/packageA'
    assert_response :success
  end

  def do_test_change_package_meta(project, package, response1, response2, tag2, response3, select3)
    get url_for(controller: :source_package_meta, action: :show, project: project, package: package)
    assert_response response1
    unless response2 || tag2 || response3 || select3
      # dummy write to check blocking
      put url_for(controller: :source_package_meta, action: :update, project: project, package: package), params: "<package name=\"#{package}\"><title></title><description></description></package>"
      assert_response :not_found
      #      assert_match(/unknown_package/, @response.body)
      assert_match(/unknown_project/, @response.body)
      return
    end
    xml = @response.body
    doc = REXML::Document.new(xml)
    d = doc.elements['/package']
    b = d.add_element 'build'
    b.add_element 'enable'
    put url_for(controller: :source_package_meta, action: :update, project: project, package: package), params: doc.to_s
    assert_response response2
    assert_xml_tag(tag2)

    get url_for(controller: :source_package_meta, action: :show, project: project, package: package)
    assert_response response3
    assert_select select3 if select3
  end

  def test_change_package_meta
    prj = 'kde4' # project
    pkg = 'kdelibs' # package
    resp1 = :success # assert response #1
    resp2 = :success # assert response #2
    atag2 = { tag: 'status', attributes: { code: 'ok' } } # assert_xml_tag after response #2
    resp3 = :success # assert respons #3
    asel3 = 'package > build > enable' # assert_select after response #3
    # user without any special roles
    login_fred
    do_test_change_package_meta(prj, pkg, resp1, resp2, atag2, resp3, asel3)
  end

  def test_change_package_meta_hidden
    prj = 'HiddenProject'
    pkg = 'pack'
    # uninvolved user
    resp1 = 404
    resp2 = nil
    atag2 = nil
    resp3 = nil
    asel3 = nil
    login_fred
    do_test_change_package_meta(prj, pkg, resp1, resp2, atag2, resp3, asel3)
    resp1 = :success
    resp2 = :success
    atag2 = { tag: 'status', attributes: { code: 'ok' } }
    resp3 = :success
    asel3 = 'package > build > enable'
    # maintainer
    login_adrian
    do_test_change_package_meta(prj, pkg, resp1, resp2, atag2, resp3, asel3)
  end

  def test_change_package_meta_sourceaccess_protect
    prj = 'SourceprotectedProject'
    pkg = 'pack'
    # uninvolved user
    resp1 = :success
    resp2 = 403
    atag2 = { tag: 'status', attributes: { code: 'update_project_not_authorized' } }
    resp3 = :success
    asel3 = nil
    login_fred
    do_test_change_package_meta(prj, pkg, resp1, resp2, atag2, resp3, asel3)

    # maintainer
    resp1 = :success
    resp2 = :success
    atag2 = { tag: 'status', attributes: { code: 'ok' } }
    resp3 = :success
    asel3 = 'package > build > enable'
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    do_test_change_package_meta(prj, pkg, resp1, resp2, atag2, resp3, asel3)
  end

  def test_put_invalid_package_meta
    prepare_request_with_user('fredlibs', 'buildservice')
    # Get meta file
    get url_for(controller: :source_package_meta, action: :show, project: 'kde4', package: 'kdelibs')
    assert_response :success

    xml = @response.body
    olddoc = REXML::Document.new(xml)
    doc = REXML::Document.new(xml)
    # Write corrupt data back
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'kdelibs'), params: doc.to_s + '</xml>'
    assert_response :bad_request

    login_king
    # write to illegal location:
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: '.'), params: doc.to_s
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_package_name' }

    # must not create a package with different pathname and name in _meta.xml:
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'kdelibs2000'), params: doc.to_s
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'package_name_mismatch' }
    # verify data is unchanged:
    get url_for(controller: :source_package_meta, action: :show, project: 'kde4', package: 'kdelibs')
    assert_response :success
    assert_equal(olddoc.to_s, REXML::Document.new(@response.body).to_s)
  end

  def test_read_file
    login_tom
    get '/source/kde4/kdelibs/my_patch.diff'
    assert_response :success
    assert_equal(@response.body.to_s, 'argl')

    get '/source/kde4/kdelibs/BLUB'
    # STDERR.puts(@response.body)
    assert_response :not_found
    assert_xml_tag(tag: 'status')
  end

  def test_read_file_hidden_proj
    # nobody
    prepare_request_with_user('adrian_nobody', 'buildservice')
    get '/source/HiddenProject/pack/my_file'

    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    # uninvolved,
    login_tom
    get '/source/HiddenProject/pack/my_file'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    # reader
    # downloader
    # maintainer
    prepare_request_with_user('hidden_homer', 'buildservice')
    get '/source/HiddenProject/pack/my_file'
    assert_response :success
    assert_equal(@response.body.to_s, 'Protected Content')
    # admin
    login_king
    get '/source/HiddenProject/pack/my_file'
    assert_response :success
    assert_equal(@response.body.to_s, 'Protected Content')
  end

  def test_read_filelist_sourceaccess_proj
    # nobody
    prepare_request_with_user('adrian_nobody', 'buildservice')
    get '/source/SourceprotectedProject/pack'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'source_access_no_permission' }
    # uninvolved,
    login_tom
    get '/source/SourceprotectedProject/pack'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'source_access_no_permission' }
    # reader
    # downloader
    # maintainer
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    get '/source/SourceprotectedProject/pack'
    assert_response :success
    assert_xml_tag tag: 'directory'
    # admin
    login_king
    get '/source/SourceprotectedProject/pack'
    assert_response :success
    assert_xml_tag tag: 'directory'
  end

  def test_read_file_sourceaccess_proj
    # anonymous (testing a side-effect of ApplicationController:check_for_anonymous_user)
    get '/source/SourceprotectedProject/pack/my_file'
    assert_response :unauthorized
    assert_xml_tag tag: 'status', attributes: { code: 'authentication_required' }
    # anonymous with user-agent set
    get '/source/SourceprotectedProject/pack/my_file', headers: { 'HTTP_USER_AGENT' => 'osc-something' }
    assert_response :unauthorized
    assert_xml_tag tag: 'status', attributes: { code: 'anonymous_user' }
    # nobody
    prepare_request_with_user('adrian_nobody', 'buildservice')
    get '/source/SourceprotectedProject/pack/my_file'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'source_access_no_permission' }
    # uninvolved,
    login_tom
    get '/source/SourceprotectedProject/pack/my_file'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'source_access_no_permission' }
    # reader
    # downloader
    # maintainer
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    get '/source/SourceprotectedProject/pack/my_file'
    assert_response :success
    assert_equal(@response.body.to_s, 'Protected Content')
    # admin
    login_king
    get '/source/SourceprotectedProject/pack/my_file'
    assert_response :success
    assert_equal(@response.body.to_s, 'Protected Content')
  end

  def add_file_to_package(url1, asserttag1, url2, assertresp2,
                          assertselect2, assertselect2rev,
                          assertresp3, asserteq3, assertresp4)
    get url1
    # before md5
    assert_xml_tag asserttag1 if asserttag1
    teststring = '&;'
    put url2, params: teststring
    assert_response assertresp2
    # afterwards new md5
    assert_select assertselect2, assertselect2rev if assertselect2
    # reread file
    get url2
    assert_response assertresp3
    assert_equal teststring, @response.body if asserteq3
    # delete
    delete url2
    assert_response assertresp4
    # file gone
    get url2
    assert_response :not_found if asserteq3
  end

  private :add_file_to_package

  def test_add_file_to_package_hidden
    # uninvolved user
    prepare_request_with_user('fredlibs', 'buildservice')
    url1 = '/source/HiddenProject/pack'
    asserttag1 = { tag: 'status', attributes: { code: 'unknown_project' } }
    url2 = '/source/HiddenProject/pack/testfile'
    assertresp2 = 404
    assertselect2 = nil
    assertselect2rev = nil
    assertresp3 = 404
    asserteq3 = nil
    assertresp4 = 404
    add_file_to_package(url1, asserttag1, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
    # nobody
    prepare_request_with_user('adrian_nobody', 'buildservice')
    add_file_to_package(url1, asserttag1, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
    # maintainer
    prepare_request_with_user('hidden_homer', 'buildservice')
    asserttag1 = { tag: 'directory', attributes: { srcmd5: 'b47be8b05a188d62b40c9d65cf490618' } }
    assertresp2 = :success
    assertselect2 = 'revision > srcmd5'
    assertselect2rev = 'dbb12bebdbbcb83be4225f07d93f940d'
    assertresp3 = :success
    asserteq3 = true
    assertresp4 = :success
    add_file_to_package(url1, asserttag1, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
    # admin
    login_king
    add_file_to_package(url1, asserttag1, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
  end

  def test_add_file_to_package_sourceaccess_protect
    # uninvolved user
    prepare_request_with_user('fredlibs', 'buildservice')
    url1 = '/source/SourceprotectedProject/pack'
    url2 = '/source/SourceprotectedProject/pack/testfile'
    assertresp2 = 403
    assertselect2 = nil
    assertselect2rev = nil
    assertresp3 = 403
    asserteq3 = nil
    assertresp4 = 403
    add_file_to_package(url1, nil, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
    # nobody
    prepare_request_with_user('adrian_nobody', 'buildservice')
    add_file_to_package(url1, nil, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
    # maintainer
    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    asserttag1 = { tag: 'directory', attributes: { srcmd5: 'b47be8b05a188d62b40c9d65cf490618' } }
    assertresp2 = :success
    assertselect2 = 'revision > srcmd5'
    assertselect2rev = 'dbb12bebdbbcb83be4225f07d93f940d'
    assertresp3 = :success
    asserteq3 = true
    assertresp4 = :success
    add_file_to_package(url1, asserttag1, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
    # admin
    login_king
    add_file_to_package(url1, asserttag1, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
  end

  def test_add_file_to_package
    url1 = '/source/kde4/kdelibs'
    asserttag1 = { tag: 'directory', attributes: { srcmd5: '1636661d96a88cd985d82dc611ebd723' } }
    url2 = '/source/kde4/kdelibs/testfile'
    assertresp2 = :success
    assertselect2 = 'revision > srcmd5'
    assertselect2rev = 'bc1d31b2403fa8925b257101b96196ec'
    assertresp3 = :success
    asserteq3 = true
    assertresp4 = :success
    prepare_request_with_user('fredlibs', 'buildservice')
    add_file_to_package(url1, asserttag1, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
    login_fred
    add_file_to_package(url1, asserttag1, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
    login_king
    add_file_to_package(url1, asserttag1, url2, assertresp2,
                        assertselect2, assertselect2rev,
                        assertresp3, asserteq3, assertresp4)
    # write without permission:
    login_tom
    get url_for(controller: :source_package, action: :show_file, project: 'kde4', package: 'kdelibs', filename: 'my_patch.diff')
    assert_response :success
    origstring = @response.body.to_s
    teststring = '&;'
    put url_for(controller: :source_package, action: :show_file, project: 'kde4', package: 'kdelibs', filename: 'my_patch.diff'), params: teststring
    assert_response(:forbidden, 'Was able to write a package file without permission')
    assert_xml_tag(tag: 'status')

    # check that content is unchanged:
    get url_for(controller: :source_package, action: :show_file, project: 'kde4', package: 'kdelibs', filename: 'my_patch.diff')
    assert_response :success
    assert_equal(@response.body.to_s, origstring, 'Package file was changed without permissions')

    # invalid permission
    reset_auth
    delete '/source/kde4/kdelibs/my_patch.diff'
    assert_response :unauthorized

    prepare_request_with_user('adrian_nobody', 'buildservice')
    delete '/source/kde4/kdelibs/my_patch.diff'
    assert_response :forbidden

    get '/source/kde4/kdelibs/my_patch.diff'
    assert_response :success

    # reset file in backend to fixture setup
    put '/source/kde4/kdelibs/my_patch.diff?user=king', params: 'argl'
  end

  def test_get_package_meta_history
    get '/source/kde4/kdelibs/_history'
    assert_response :unauthorized
    prepare_request_with_user('fredlibs', 'buildservice')
    get '/source/kde4/kdelibs/_history'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    get '/source/kde4/kdelibs/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    get '/source/kde4/kdelibs/_meta'
    assert_response :success
    meta = @response.body
    put '/source/kde4/kdelibs/_meta?comment=empty+change', params: meta
    assert_response :success
    get '/source/kde4/kdelibs/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    assert_xml_tag(tag: 'comment', content: 'empty change')
  end

  def test_get_project_meta_history
    get '/source/kde4/_project/_history'
    assert_response :unauthorized
    prepare_request_with_user('fredlibs', 'buildservice')
    get '/source/kde4/_project/_history'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    get '/source/kde4/_project/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    # remember the current HEAD so we can check it later
    # value depends on the test order
    rl = Xmlhash.parse(@response.body)
    oldrevision = rl.elements('revision').last['rev']
    get '/source/kde4/_meta'
    assert_response :success
    oldmeta = @response.body
    newmeta = oldmeta.gsub(%r{<title>.*</title>}, '<title>new title string</title>')
    raw_put '/source/kde4/_meta?comment=title+change', newmeta
    assert_response :success
    get '/source/kde4/_project/_history?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'revisionlist')
    assert_xml_tag(tag: 'comment', content: 'title change')
    # compare to database version
    get '/source/kde4/_project/_meta'
    assert_response :success
    assert_xml_tag(tag: 'title', content: 'new title string')
    # compare to backend version
    get '/source/kde4/_project/_meta?meta=1&rev=latest'
    assert_response :success
    assert_xml_tag(tag: 'title', content: 'new title string')

    # check old revision
    get '/source/kde4/_project/_meta?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'project')
    get "/source/kde4/_project/_meta?meta=1&rev=#{oldrevision}"
    assert_response :success
    assert_xml_tag(tag: 'project')
    assert_xml_tag(tag: 'title', content: 'blub') # fixture string

    # restore
    raw_put '/source/kde4/_meta?comment=title+change', oldmeta
    assert_response :success
  end

  def test_get_package_meta_file
    get '/source/kde4/kdelibs/_history'
    assert_response :unauthorized
    prepare_request_with_user('fredlibs', 'buildservice')
    get '/source/kde4/kdelibs/_meta?meta=1'
    assert_response :success
    assert_xml_tag(tag: 'package')
    oldmeta = @response.body
    newmeta = oldmeta.gsub(%r{<title>.*</title>}, '<title>new package title string</title>')
    raw_put '/source/kde4/kdelibs/_meta?comment=title+change', newmeta
    assert_response :success
    # compare to database version
    get '/source/kde4/kdelibs/_meta'
    assert_response :success
    assert_xml_tag(tag: 'package')
    assert_xml_tag(tag: 'title', content: 'new package title string')
    # compare to backend version
    get '/source/kde4/kdelibs/_meta?meta=1&rev=latest'
    assert_response :success
    assert_xml_tag(tag: 'package')
    assert_xml_tag(tag: 'title', content: 'new package title string')

    # old revision
    get '/source/kde4/kdelibs/_meta?meta=1&rev=1'
    assert_response :success
    assert_xml_tag(tag: 'package')
    assert_xml_tag(tag: 'title', content: 'blub') # fixture string

    # restore
    raw_put '/source/kde4/kdelibs/_meta', oldmeta
    assert_response :success
  end

  def test_package_command_without_cmd_parameter
    prepare_request_with_user('fredlibs', 'buildservice')
    post '/source/kde4/kdelibs'
    assert_response :not_found
  end

  def test_package_command_with_invalid_cmd_parameter
    prepare_request_with_user('fredlibs', 'buildservice')
    post '/source/kde4/kdelibs', params: { cmd: :invalid }
    assert_response :not_found
  end

  def test_blame_view
    prepare_request_with_user('fredlibs', 'buildservice')
    raw_put '/source/kde4/BLAME/_meta', '<package name="BLAME" project="kde4"><title/><description/></package>'
    assert_response :success

    raw_put '/source/kde4/BLAME/DUMMYFILE', "init\n"
    assert_response :success

    # store current revision
    get '/source/kde4/BLAME/_history'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    rev = node.elements('revision').last['rev'].to_i

    # add a file
    raw_put '/source/kde4/BLAME/DUMMYFILE', "dummy1\ndummy2\ndummy3\n"
    assert_response :success
    login_king
    raw_put '/source/kde4/BLAME/DUMMYFILE', "dummy1\ndummy2 king\ndummy3\n"
    assert_response :success

    get '/source/kde4/BLAME/DUMMYFILE?view=blame'
    assert_response :success
    assert_match(/#{rev + 1} \(fredlibs .* 1\) dummy1/, @response.body)
    assert_match(/#{rev + 2} \(king     .* 2\) dummy2 king/, @response.body)
    assert_match(/#{rev + 1} \(fredlibs .* 3\) dummy3/, @response.body)

    # meta view needs special routing
    get '/source/kde4/BLAME/_meta?view=blame&meta=1'
    assert_response :success
    assert_match(/^   1 \(fredlibs/, @response.body)
    get '/source/kde4/_project/_meta?view=blame&meta=1'
    assert_response :success
    assert_match(/^   1 \(king/, @response.body)
    # should also work without the extra meta argument since it is _meta
    get '/source/kde4/_project/_meta?view=blame'
    assert_response :success
    assert_match(/^   1 \(king/, @response.body)

    # cleanup
    delete '/source/kde4/BLAME'
    assert_response :success
  end

  def test_remove_and_undelete_operations
    delete '/source/kde4/kdelibs'
    assert_response :unauthorized
    delete '/source/kde4'
    assert_response :unauthorized

    # delete single package in project
    prepare_request_with_user('fredlibs', 'buildservice')
    put '/source/kde4/kdelibs/DUMMYFILE', params: 'dummy'
    assert_response :success
    # to have different revision number in meta and plain files
    delete '/source/kde4/kdelibs?user=illegal&comment=test%20deleted'
    assert_response :success

    get '/source/kde4/kdelibs'
    assert_response :not_found
    get '/source/kde4/kdelibs/_meta'
    assert_response :not_found

    # check history
    get '/source/kde4/kdelibs/_history?deleted=1'
    assert_response :success
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'user', content: 'fredlibs')
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'comment', content: 'test deleted')
    get '/source/kde4/kdelibs/_history?meta=1&deleted=1'
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'user', content: 'fredlibs')
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'comment', content: 'test deleted')
    assert_response :success
    # source access check via public route (critical for obs-git-lfs-ro)
    get '/source/kde4/kdelibs?deleted=1'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    srcmd5 = node['srcmd5']
    get "/public/source/kde4/kdelibs/DUMMYFILE?rev=#{srcmd5}"
    assert_response :success

    # list deleted packages of existing project
    get '/source/kde4', params: { deleted: 1 }
    assert_response :success
    assert_xml_tag(tag: 'entry', attributes: { name: 'kdelibs' })

    # access to files of a deleted package
    get '/source/kde4/kdelibs/_history'
    assert_response :not_found
    get '/source/kde4/kdelibs/_history', params: { deleted: 1 }
    assert_response :success
    node = Xmlhash.parse(@response.body)
    srcmd5 = node.elements('revision').last['srcmd5']
    get '/source/kde4/kdelibs', params: { deleted: 1, rev: srcmd5 }
    assert_response :success
    get '/source/kde4/kdelibs/my_patch.diff', params: { rev: srcmd5 }
    assert_response :not_found
    get '/source/kde4/kdelibs/my_patch.diff', params: { deleted: 1, rev: srcmd5 }
    assert_response :success
    get '/source/kde4/kdelibs/my_patch.diff', params: { deleted: 1 }
    assert_response :success

    # undelete single package
    post '/source/kde4/kdelibs', params: { cmd: :undelete, time: 99 }
    assert_response :forbidden
    assert_match(/Only administrators are allowed to set the time/, @response.body)
    post '/source/kde4/kdelibs', params: { cmd: :undelete }
    assert_response :success
    get '/source/kde4/kdelibs/_history'
    assert_response :success
    assert_no_xml_tag(tag: 'time', content: '99')
    get '/source/kde4/kdelibs/_meta'
    assert_response :success

    # admin only operations
    prepare_request_with_user('fredlibs', 'buildservice')
    delete '/source/kde4/kdelibs'
    assert_response :success
    login_king
    post '/source/kde4/kdelibs', params: { cmd: :undelete, time: 99 }
    assert_response :bad_request
    assert_match(/specified time is less than time in last commit/, @response.body)
    mytime = Time.now.utc.to_i + 2
    post '/source/kde4/kdelibs', params: { cmd: :undelete, time: mytime }
    assert_response :success
    get '/source/kde4/kdelibs/_history'
    assert_response :success
    assert_xml_tag(tag: 'time', content: mytime)

    # delete entire project
    prepare_request_with_user('fredlibs', 'buildservice')
    get '/source/kde4/_meta'
    assert_response :success
    meta_before_delete = @response.body
    # kind of stupid, but do_change_project_meta_test modifies backend data and does not clean up
    put '/source/kde4/_meta', params: meta_before_delete
    assert_response :success
    get '/source/kde4/_project/_history?meta=1'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    revision = node.elements('revision').last['rev']
    expected_revision = revision.to_i + 1
    delete '/source/kde4?user=illegal&comment=drop%20project'
    assert_response :success

    get '/source/kde4'
    assert_response :not_found
    get '/source/kde4/_meta'
    assert_response :not_found

    # list deleted packages of deleted project
    # FIXME: not yet supported
    #    get "/source/kde4", :deleted => 1
    #    assert_response :success
    #    assert_xml_tag( :tag => "entry", :attributes => { :name => "kdelibs"} )

    # admin only operations
    login_king
    # list content of deleted project
    get '/source', params: { deleted: 1 }
    assert_response :ok
    assert_xml_tag(tag: 'entry', attributes: { name: 'kde4' })

    prepare_request_with_user('fredlibs', 'buildservice')
    get '/source', params: { deleted: 1 }
    assert_response :forbidden
    assert_match(/only admins can see deleted projects/, @response.body)

    # check history
    get '/source/kde4/_project/_history?deleted=1'
    assert_response :success
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'user', content: 'fredlibs')
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'comment', content: 'drop project')
    get '/source/kde4/_project/_history?meta=1&deleted=1'
    assert_response :success
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'user', content: 'fredlibs')
    assert_xml_tag(parent: { tag: 'revision' }, tag: 'comment', content: 'drop project')
    # there must be only one change
    node = Xmlhash.parse(@response.body)
    revision = node.elements('revision').last['rev']
    assert_equal expected_revision, revision.to_i

    prepare_request_with_user('fredlibs', 'buildservice')
    # undelete project
    post '/source/kde4', params: { cmd: :undelete }
    assert_response :forbidden

    login_king
    post '/source/kde4', params: { cmd: :undelete }
    assert_response :success

    # content got restored ?
    get '/source/kde4'
    assert_response :success
    get '/source/kde4/_project'
    assert_response :success
    get '/source/kde4/_meta'
    assert_response :success
    assert_equal meta_before_delete, @response.body
    get '/source/kde4/kdelibs'
    assert_response :success
    get '/source/kde4/kdelibs/_meta'
    assert_response :success
    get '/source/kde4/kdelibs/my_patch.diff'
    assert_response :success
    delete '/source/kde4/kdelibs/DUMMYFILE' # restore as before
    assert_response :success

    # undelete project again
    post '/source/kde4', params: { cmd: :undelete }
    assert_response :not_found
    assert_match(/project 'kde4' already exists/, @response.body)
  end

  def test_remove_project_and_verify_repositories
    login_tom
    get '/source/home:coolo:test/_meta'
    assert_response :success

    delete '/source/home:coolo'
    assert_response :bad_request
    assert_select 'status[code] > summary', /following repositories depend on this project:/

    delete '/source/home:coolo', params: { force: 1 }
    assert_response :success

    # verify the repo is updated
    get '/source/home:coolo:test/_meta'
    assert_response :success
    node = Xmlhash.parse(@response.body)['repository']
    assert_equal 'home_coolo', node['name']
    assert_equal 'deleted', node['path']['project']
    assert_equal 'deleted', node['path']['repository']

    # restore
    login_king
    post '/source/home:coolo', params: { cmd: :undelete }
    assert_response :success
  end

  def test_diff_package
    login_tom
    post '/source/home:Iggy/TestPack?oproject=kde4&opackage=kdelibs&cmd=diff'
    assert_response :success
  end

  def test_meta_diff_package
    login_tom
    post '/source/home:Iggy/TestPack?oproject=kde4&opackage=kdelibs&cmd=diff&meta=1'
    assert_response :success
    assert_match(%r{</package>}, @response.body)

    post '/source/home:Iggy/_project?oproject=kde4&opackage=_project&cmd=diff&meta=1'
    assert_response :success
    assert_match(%r{</project>}, @response.body)
  end

  def test_diff_package_hidden_project
    login_tom
    post '/source/HiddenProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    # reverse
    post '/source/kde4/kdelibs?oproject=HiddenProject&opackage=pack&cmd=diff'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' } # was package

    prepare_request_with_user('hidden_homer', 'buildservice')
    post '/source/HiddenProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff'
    assert_response :success
    assert_match(/Minimal rpm package for testing the build controller/, @response.body)
    # reverse
    post '/source/kde4/kdelibs?oproject=HiddenProject&opackage=pack&cmd=diff'
    assert_response :success
    assert_match(/argl/, @response.body)

    login_king
    post '/source/HiddenProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff'
    assert_response :success
    assert_match(/Minimal rpm package for testing the build controller/, @response.body)
    # reverse
    login_king
    post '/source/kde4/kdelibs?oproject=HiddenProject&opackage=pack&cmd=diff'
    assert_response :success
    assert_match(/argl/, @response.body)
  end

  def test_diff_package_sourceaccess_protected_project
    login_tom
    post '/source/SourceprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'source_access_no_permission' }
    # reverse
    post '/source/kde4/kdelibs?oproject=SourceprotectedProject&opackage=pack&cmd=diff'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'source_access_no_permission' }

    prepare_request_with_user('sourceaccess_homer', 'buildservice')
    post '/source/SourceprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff'
    assert_response :success
    assert_match(/Protected Content/, @response.body)
    # reverse
    post '/source/kde4/kdelibs?oproject=SourceprotectedProject&opackage=pack&cmd=diff'
    assert_response :success
    assert_match(/argl/, @response.body)

    login_king
    post '/source/SourceprotectedProject/pack?oproject=kde4&opackage=kdelibs&cmd=diff'
    assert_response :success
    assert_match(/Protected Content/, @response.body)
    # reverse
    login_king
    post '/source/kde4/kdelibs?oproject=SourceprotectedProject&opackage=pack&cmd=diff'
    assert_response :success
    assert_match(/argl/, @response.body)
  end

  def test_constraints
    login_tom
    get '/source/home:coolo:test'
    assert_response :success
    put '/source/home:coolo:test/_project/_constraints', params: 'illegal'
    assert_response :bad_request
    assert_match(/validation error/, @response.body)
    put '/source/home:coolo:test/_project/_constraints', params: '<constraints> <hardware> <processors>3</processors> </hardware> </constraints>'
    assert_response :success
    put '/source/home:coolo:test/test/_meta', params: "<package project='home:coolo:test' name='test'><title/><description/></package>"
    assert_response :success
    put '/source/home:coolo:test/test/_constraints', params: '<constraints> <linux> <version><min>1.0</min></version> </linux> </constraints>'
    assert_response :success

    # cleanup
    delete '/source/home:coolo:test/_project/_constraints'
    assert_response :success
    delete '/source/home:coolo:test/test'
    assert_response :success
  end

  def test_pattern
    put '/source/kde4/_pattern/mypattern', params: load_backend_file('pattern/digiKam.xml')
    assert_response :unauthorized

    prepare_request_with_user('adrian_nobody', 'buildservice')
    get '/source/DoesNotExist/_pattern'
    assert_response :not_found
    get '/source/kde4/_pattern'
    assert_response :success
    get '/source/kde4/_pattern/DoesNotExist'
    assert_response :not_found
    put '/source/kde4/_pattern/mypattern', params: load_backend_file('pattern/digiKam.xml')
    assert_response :forbidden
    assert_match(/put_file_no_permission/, @response.body)

    login_tom
    get '/source/home:coolo:test'
    assert_response :success
    assert_no_match(/_pattern/, @response.body)
    put '/source/home:coolo:test/_pattern/mypattern', params: 'broken'
    assert_response :bad_request
    assert_match(/validation error/, @response.body)
    put '/source/home:coolo:test/_pattern/mypattern', params: load_backend_file('pattern/digiKam.xml')
    assert_response :success
    get '/source/home:coolo:test/_pattern/mypattern'
    assert_response :success
    get '/source/home:coolo:test'
    assert_response :success
    assert_match(/_pattern/, @response.body)

    # verify a pattern file (_pattern package exists)
    put '/source/home:coolo:test/_pattern/mypattern', params: 'broken'
    assert_response :bad_request

    # delete failure
    prepare_request_with_user('adrian_nobody', 'buildservice')
    delete '/source/home:coolo:test/_pattern/mypattern'
    assert_response :forbidden

    # successfull delete
    login_tom
    delete '/source/home:coolo:test/_pattern/mypattern'
    assert_response :success
    delete '/source/home:coolo:test/_pattern/mypattern'
    assert_response :not_found
    delete '/source/home:coolo:test/_pattern'
    assert_response :success
    delete '/source/home:coolo:test/_pattern'
    assert_response :not_found
  end

  def test_prjconf
    get url_for(controller: :source_project_config, action: :show, project: 'DoesNotExist')
    assert_response :unauthorized
    prepare_request_with_user('adrian_nobody', 'buildservice')
    get url_for(controller: :source_project_config, action: :show, project: 'DoesNotExist')
    assert_response :not_found
    get url_for(controller: :source_project_config, action: :show, project: 'kde4')
    assert_response :success
    get url_for(controller: :source_project_config, action: :show, project: 'RemoteInstance:BaseDistro')
    assert_response :success

    put url_for(controller: :source_project_config, action: :update, project: 'RemoteInstance:BaseDistro'), params: 'Substitute: nix da'
    assert_response :forbidden

    prepare_request_with_user('adrian_nobody', 'buildservice')
    put url_for(controller: :source_project_config, action: :update, project: 'kde4'), params: 'Substitute: nix da'
    assert_response :forbidden

    login_tom
    put url_for(controller: :source_project_config, action: :update, project: 'home:coolo:test'), params: 'Substitute: nix da'
    assert_response :success
    get url_for(controller: :source_project_config, action: :show, project: 'home:coolo:test')
    assert_response :success
  end

  def test_public_keys
    login_tom
    # old route
    get '/source/DoesNotExist/_pubkey'
    assert_response :not_found
    get '/source/kde4/_pubkey'
    assert_response :not_found
    assert_match(/kde4: no pubkey available/, @response.body)
    get '/source/BaseDistro/_pubkey'
    assert_response :success

    delete '/source/kde4/_pubkey'
    assert_response :forbidden

    login_king
    subprojectmeta = "<project name='DoesNotExist:subproject'><title></title><description/></project>"
    put url_for(controller: :source_project_meta, action: :update, project: 'DoesNotExist:subproject'), params: subprojectmeta
    assert_response :success

    delete '/source/DoesNotExist:subproject/_pubkey'
    assert_response :success

    delete '/source/DoesNotExist:subproject'
    assert_response :success

    login_tom

    # FIXME: make a successful deletion of a key

    # via new _project route
    get '/source/DoesNotExist/_project/_pubkey?meta=1'
    assert_response :not_found
    get '/source/kde4/_project/_pubkey?meta=1'
    assert_response :not_found
    assert_match(/no such file/, @response.body)
    get '/source/BaseDistro/_project/?meta=1'
    get '/source/BaseDistro/_project/_pubkey?meta=1'
    assert_response :success

    delete '/source/kde4/_project/_pubkey?meta=1'
    assert_response :forbidden

    # ssl certificate
    get '/source/DoesNotExist/_project/_sslcert?meta=1'
    assert_response :not_found
    get '/source/kde4/_project/_sslcert?meta=1'
    assert_response :not_found
    assert_match(/no such file/, @response.body)
    get '/source/BaseDistro/_project/_sslcert?meta=1'
    assert_response :success

    delete '/source/kde4/_project/_sslcert?meta=1'
    assert_response :forbidden
  end

  def test_linked_project_operations
    # first go with a read-only user
    login_tom
    # listings
    get '/source/BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
    assert_xml_tag(tag: 'directory', attributes: { count: '1' })
    get '/source/BaseDistro2.0:LinkedUpdateProject?expand=1'
    assert_response :success
    assert_xml_tag(tag: 'directory', attributes: { count: '3' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2', originproject: 'BaseDistro2.0' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'pack2.linked', originproject: 'BaseDistro2.0' })

    # pack2 exists only via linked project
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/pack2'
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)

    # test not permitted commands
    post '/build/BaseDistro2.0:LinkedUpdateProject', params: { cmd: 'rebuild' }
    assert_response :forbidden
    post '/build/BaseDistro2.0:LinkedUpdateProject', params: { cmd: 'wipe' }
    assert_response :forbidden
    assert_match(/permission to execute command on project BaseDistro2.0:LinkedUpdateProject/, @response.body)
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: 'deleteuploadrev' }
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: 'commitfilelist' }
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: 'commit' }
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: 'linktobranch' }
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)

    # test permitted commands
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: 'diff', oproject: 'RemoteInstance:BaseDistro', opackage: 'pack1' }
    assert_response :success
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: 'branch' }
    assert_response :success
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2.linked', params: { cmd: 'linkdiff' }
    assert_response :success

    # read-write user, binary operations must be allowed
    login_king
    # obsolete with OBS 3.0, rebuild only via /build/
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: 'rebuild' }
    assert_response :success
    post '/build/BaseDistro2.0:LinkedUpdateProject', params: { cmd: 'rebuild', package: 'pack2' }
    assert_response :success
    post '/build/BaseDistro2.0:LinkedUpdateProject', params: { cmd: 'wipe' }
    assert_response :success

    # create package and remove it again
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/pack2'
    assert_response :not_found
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: 'copy', oproject: 'BaseDistro:Update', opackage: 'pack2' }
    assert_response :success
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: 'undelete' }
    assert_response :bad_request # already exists
    assert_match(/package_exists/, @response.body)
    delete '/source/BaseDistro2.0:LinkedUpdateProject/pack2'
    assert_response :success
    post '/source/BaseDistro2.0:LinkedUpdateProject/pack2', params: { cmd: 'undelete' }
    assert_response :success
    get '/source/BaseDistro2.0:LinkedUpdateProject/pack2'
    assert_response :success

    # cleanup
    delete '/source/home:tom:branches:BaseDistro2.0:LinkedUpdateProject'
    assert_response :success
    delete '/source/BaseDistro2.0:LinkedUpdateProject/pack2'
    assert_response :success
  end

  def test_linktobranch
    login_Iggy
    put '/source/home:Iggy/TestLinkPack/_meta', params: "<package project='home:Iggy' name='TestLinkPack'> <title/> <description/> </package>"
    assert_response :success
    put '/source/home:Iggy/TestLinkPack/_link', params: "<link package='TestPack' />"
    assert_response :success

    login_fred
    post '/source/home:Iggy/TestLinkPack?cmd=linktobranch'
    assert_response :forbidden

    login_Iggy
    post '/source/home:Iggy/TestLinkPack?cmd=linktobranch'
    assert_response :success
    get '/source/home:Iggy/TestLinkPack/_link'
    assert_response :success
    assert_xml_tag(tag: 'link', attributes: { package: 'TestPack' })
    assert_xml_tag(parent: { tag: 'patches', content: nil }, tag: 'branch', content: nil)

    delete '/source/home:Iggy/TestLinkPack'
    assert_response :success
  end

  def test_branch_images_repo_without_path
    login_adrian
    put '/source/home:adrian:IMAGES/_meta', params: "<project name='home:adrian:IMAGES'> <title/> <description/>
          <repository name='images'>
            <arch>i586</arch>
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success

    put '/source/home:adrian:IMAGES/appliance/_meta', params: "<package project='home:adrian:IMAGES' name='appliance'> <title/> <description/> </package>"
    assert_response :success

    post '/source/home:adrian:IMAGES/appliance', params: { cmd: 'branch', add_repositories: 1 }
    assert_response :success

    get '/source/home:adrian:branches:home:adrian:IMAGES/_meta'
    assert_response :success
    assert_xml_tag(tag: 'repository', attributes: { name: 'images' })
    assert_no_xml_tag(tag: 'path')

    get '/source/home:adrian:branches:home:adrian:IMAGES/_config'
    assert_response :success
    assert_match(/Type: kiwi/, @response.body)

    # cleanup
    delete '/source/home:adrian:branches:home:adrian:IMAGES'
    assert_response :success
    delete '/source/home:adrian:IMAGES'
    assert_response :success
  end

  def test_branch_repository_with_extra_policy
    login_adrian
    put '/source/home:adrian:TEMP/_meta', params: "<project name='home:adrian:TEMP'> <title/> <description/>
          <repository name='repo1' rebuild='local'>
            <arch>x86_64</arch>
          </repository>
          <repository name='repo2' rebuild='transitive'>
            <arch>x86_64</arch>
          </repository>
          <repository name='repo3'>
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success
    put '/source/home:adrian:TEMP/dummy/_meta', params: "<package project='home:adrian:TEMP' name='dummy'> <title/> <description/> </package>"
    assert_response :success

    # without attribute
    post '/source/home:adrian:TEMP/dummy', params: { cmd: 'branch', add_repositories: 1, add_repositories_rebuild: :local, add_repositories_block: :never }
    assert_response :success
    get '/source/home:adrian:branches:home:adrian:TEMP/_meta'
    assert_response :success
    assert_xml_tag(tag: 'repository', attributes: { name: 'repo1', rebuild: 'local', block: 'never' })
    assert_xml_tag(tag: 'repository', attributes: { name: 'repo2', rebuild: 'local', block: 'never' })
    assert_xml_tag(tag: 'repository', attributes: { name: 'repo3', rebuild: 'local', block: 'never' })
    delete '/source/home:adrian:branches:home:adrian:TEMP'
    assert_response :success

    # copy rebuild strategy when branching
    post '/source/home:adrian:TEMP/dummy', params: { cmd: 'branch', add_repositories: 1, add_repositories_rebuild: :copy }
    assert_response :success
    get '/source/home:adrian:branches:home:adrian:TEMP/_meta'
    assert_response :success
    assert_xml_tag(tag: 'repository', attributes: { name: 'repo1', rebuild: 'local' })
    assert_xml_tag(tag: 'repository', attributes: { name: 'repo2', rebuild: 'transitive' })
    assert_xml_tag(tag: 'repository', attributes: { name: 'repo3' })
    delete '/source/home:adrian:branches:home:adrian:TEMP'
    assert_response :success

    # invalid policy
    post '/source/home:adrian:TEMP/dummy', params: { cmd: 'branch', add_repositories: 1, add_repositories_rebuild: :WRONG }
    assert_response :bad_request
    post '/source/home:adrian:TEMP/dummy', params: { cmd: 'branch', add_repositories: 1, add_repositories_block: :WRONG }
    assert_response :bad_request

    # cleanup
    delete '/source/home:adrian:TEMP'
    assert_response :success
  end

  def test_branch_repository_attribute_tests
    login_adrian
    put '/source/home:adrian:TEMP/_meta', params: "<project name='home:adrian:TEMP'> <title/> <description/>
          <repository name='repo1'>
            <arch>x86_64</arch>
          </repository>
          <repository name='repo2'>
            <arch>x86_64</arch>
          </repository>
          <repository name='repo3'>
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success
    put '/source/home:adrian:TEMP/dummy/_meta', params: "<package project='home:adrian:TEMP' name='dummy'> <title/> <description/> </package>"
    assert_response :success

    # without attribute
    post '/source/home:adrian:TEMP/dummy', params: { cmd: 'branch', add_repositories: 1 }
    assert_response :success
    get '/source/home:adrian:branches:home:adrian:TEMP/_meta'
    assert_response :success
    assert_xml_tag(tag: 'repository', attributes: { name: 'repo1' })
    assert_xml_tag(tag: 'repository', attributes: { name: 'repo2' })
    assert_xml_tag(tag: 'repository', attributes: { name: 'repo3' })
    delete '/source/home:adrian:branches:home:adrian:TEMP'
    assert_response :success

    # use repos from other project
    login_king
    post '/source/home:adrian:TEMP/_attribute', params: "
        <attributes><attribute namespace='OBS' name='BranchRepositoriesFromProject'>
          <value>BaseDistro</value>
        </attribute></attributes>"
    assert_response :success
    login_adrian
    post '/source/home:adrian:TEMP/dummy', params: { cmd: 'branch', add_repositories: 1 }
    assert_response :success
    get '/source/home:adrian:branches:home:adrian:TEMP/_meta'
    assert_response :success
    assert_xml_tag(tag: 'repository', attributes: { name: 'BaseDistro_repo' })
    assert_no_xml_tag(tag: 'repository', attributes: { name: 'repo1' })
    assert_no_xml_tag(tag: 'repository', attributes: { name: 'repo2' })
    assert_no_xml_tag(tag: 'repository', attributes: { name: 'repo3' })
    delete '/source/home:adrian:branches:home:adrian:TEMP'
    assert_response :success
    delete '/source/home:adrian:TEMP/_attribute/OBS:BranchRepositoriesFromProject'
    assert_response :success

    # use just some repositories
    login_king
    post '/source/home:adrian:TEMP/_attribute', params: "
        <attributes><attribute namespace='OBS' name='BranchSkipRepositories'>
          <value>repo1</value><value>repo3</value>
        </attribute></attributes>"
    assert_response :success
    login_adrian
    post '/source/home:adrian:TEMP/dummy', params: { cmd: 'branch', add_repositories: 1 }
    assert_response :success
    get '/source/home:adrian:branches:home:adrian:TEMP/_meta'
    assert_response :success
    assert_no_xml_tag(tag: 'repository', attributes: { name: 'repo1' })
    assert_xml_tag(tag: 'repository', attributes: { name: 'repo2' })
    assert_no_xml_tag(tag: 'repository', attributes: { name: 'repo3' })
    delete '/source/home:adrian:branches:home:adrian:TEMP'
    assert_response :success
    # again as maintenance branch
    post '/source/home:adrian:TEMP/dummy', params: { cmd: 'branch', maintenance: 1 }
    assert_response :success
    get '/source/home:adrian:branches:home:adrian:TEMP/_meta'
    assert_response :success
    assert_no_xml_tag(tag: 'repository', attributes: { name: 'home_adrian_TEMP_repo1' })
    assert_xml_tag(tag: 'repository', attributes: { name: 'home_adrian_TEMP_repo2' })
    assert_no_xml_tag(tag: 'repository', attributes: { name: 'home_adrian_TEMP_repo3' })
    delete '/source/home:adrian:branches:home:adrian:TEMP'
    assert_response :success

    # cleanup
    delete '/source/home:adrian:TEMP/_attribute/OBS:BranchSkipRepositories'
    assert_response :success
    delete '/source/home:adrian:TEMP'
    assert_response :success
  end

  def test_branch_images_repo_with_path
    login_adrian
    put '/source/home:adrian:IMAGES/_meta', params: "<project name='home:adrian:IMAGES'> <title/> <description/>
          <repository name='images'>
            <path project='BaseDistro' repository='BaseDistro_repo' />
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success

    put '/source/home:adrian:IMAGES/appliance/_meta', params: "<package project='home:adrian:IMAGES' name='appliance'> <title/> <description/> </package>"
    assert_response :success

    post '/source/home:adrian:IMAGES/appliance', params: { cmd: 'branch', add_repositories: 1 }
    assert_response :success

    get '/source/home:adrian:branches:home:adrian:IMAGES/_meta'
    assert_response :success
    assert_xml_tag(tag: 'repository', attributes: { name: 'images' })
    assert_xml_tag(tag: 'path', attributes: { project: 'BaseDistro', repository: 'BaseDistro_repo' })

    get '/source/home:adrian:branches:home:adrian:IMAGES/_config'
    assert_response :success
    assert_match(/Type: kiwi/, @response.body)

    delete '/source/home:adrian:branches:home:adrian:IMAGES'
    assert_response :success
    delete '/source/home:adrian:IMAGES'
    assert_response :success
  end

  def test_release_project
    # create manual release target
    login_adrian
    put '/source/home:adrian:RT/_meta', params: "<project name='home:adrian:RT'> <title/> <description/>
          <person userid='adrian' role='maintainer'/>
          <repository name='rt'>
            <arch>i586</arch>
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success

    # workaround of testsuite breakage, database object gets restored during
    # request controller run, but backend part not
    login_Iggy
    get '/source/home:Iggy/ToBeDeletedTestPack/_meta'
    assert_response :success
    put '/source/home:Iggy/ToBeDeletedTestPack/_meta', params: @response.body
    assert_response :success

    run_scheduler('i586')
    run_scheduler('x86_64')

    get '/source/home:Iggy/_meta'
    assert_response :success
    orig_project_meta = @response.body
    doc = REXML::Document.new(@response.body)
    person = doc.elements['/project'].add_element 'person'
    person.add_attribute(REXML::Attribute.new('userid', 'adrian'))
    person.add_attribute(REXML::Attribute.new('role', 'maintainer'))
    rt = doc.elements['/project/repository'].add_element 'releasetarget'
    rt.add_attribute(REXML::Attribute.new('project', 'home:adrian:RT'))
    rt.add_attribute(REXML::Attribute.new('repository', 'rt'))
    put '/source/home:Iggy/_meta', params: doc.to_s
    assert_response :success

    # try to release with incorrect trigger
    login_adrian
    post '/source/home:Iggy?cmd=release'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'no_matching_release_target' }
    assert_match(/Trigger is not set to manual in any repository/, @response.body)

    # add correct trigger
    login_Iggy
    rt.add_attribute(REXML::Attribute.new('trigger', 'manual'))
    put '/source/home:Iggy/_meta', params: doc.to_s
    assert_response :success

    # this user is not allowed
    post '/source/home:Iggy/TestPack?cmd=release'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'cmd_execution_no_permission' }

    # and they can release it to own space
    login_Iggy
    post '/source/home:Iggy/TestPack?cmd=release&target_project=home:Iggy'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'missing_parameter' }

    post '/source/home:Iggy/TestPack?cmd=release&target_project=home:Iggy:TEST&repository=10.2&target_repository=10.2'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    # create project
    doc.root.attributes['name'] = 'home:Iggy:TEST'
    put '/source/home:Iggy:TEST/_meta', params: doc.to_s
    assert_response :success
    # but now it works for real
    post '/source/home:Iggy/TestPack?cmd=release&target_project=home:Iggy:TEST&repository=10.2&target_repository=10.2'
    assert_response :success
    delete '/source/home:Iggy:TEST'
    assert_response :success

    # release entire project as well to default target
    login_adrian
    post '/source/home:Iggy?cmd=release'
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { code: 'invoked' }
    # just invoked, it will not get executed in test suite
    # so try it again without delay
    post '/source/home:Iggy?cmd=release&nodelay=1'
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { code: 'ok' }

    # process events
    run_scheduler('i586')

    # verify result
    get '/source/home:adrian:RT'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'TestPack' }

    # compare source with target repo
    get '/build/home:Iggy/10.2/i586/TestPack/'
    assert_response :success
    assert_xml_tag tag: 'binarylist', children: { count: 4 }

    get '/build/home:adrian:RT/rt/i586/TestPack/'
    assert_response :success
    assert_xml_tag tag: 'binarylist', children: { count: 4 }

    # cleanup
    login_Iggy
    put '/source/home:Iggy/_meta', params: orig_project_meta
    assert_response :success
    login_adrian
    delete '/source/home:adrian:RT'
    assert_response :success
  end

  def test_fork_simple_package
    login_adrian
    put '/source/home:adrian:IMAGES/_meta', params: "<project name='home:adrian:IMAGES'> <title/> <description/>
          <repository name='images'>
            <arch>i586</arch>
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success

    put '/source/home:adrian:IMAGES/appliance/_meta', params: "<package project='home:adrian:IMAGES' name='appliance'> <title/> <description/> <scmsync>http://localhost</scmsync> </package>"
    assert_response :success

    # ensure we send a proper error message to osc
    raw_post '/source/home:adrian:IMAGES/appliance?cmd=commitfilelist', ' <directory></directory> '
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { origin: 'backend' }
    assert_select 'status[code] > summary', /Package appliance is controlled by obs-scm/
    raw_put '/source/home:adrian:IMAGES/appliance/filename?rev=repository', '123'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'scmsync_read_only' }
    raw_post '/source/home:adrian:IMAGES/appliance?cmd=commitfilelist', ' <directory> <entry name="filename" md5="ba1f2511fc30423bdbb183fe33f3dd0f" /> </directory> '
    assert_response :success
    assert_xml_tag tag: 'directory', attributes: { error: 'missing' }
    post '/source/home:adrian:IMAGES/appliance', params: { cmd: 'commit' }
    assert_response :bad_request
    assert_select 'status[code] > summary', /Package appliance is controlled by obs-scm/

    login_tom
    post '/source/home:adrian:IMAGES/appliance', params: { cmd: 'fork' }
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'missing_parameter' })

    post '/source/home:adrian:IMAGES/appliance', params: { cmd: 'fork', scmsync: 'http://127.0.0.1' }
    assert_response :success

    post '/source/home:adrian:IMAGES/appliance', params: { cmd: 'fork', scmsync: 'http://127.0.0.1',
                                                           target_project: 'home:adrian:SOMEWHERE' }
    assert_response :forbidden

    get '/source/home:tom:branches:home:adrian:IMAGES/appliance/_history'
    assert_response :success
    assert_no_xml_tag(tag: 'revision')

    get '/source/home:tom:branches:home:adrian:IMAGES/_meta'
    assert_response :success
    assert_xml_tag(tag: 'repository', attributes: { name: 'images' })
    assert_no_xml_tag(tag: 'path')

    get '/source/home:tom:branches:home:adrian:IMAGES/appliance/_meta'
    assert_response :success
    assert_xml_tag(tag: 'scmsync', content: 'http://127.0.0.1')

    get '/search/package', params: { match: '[scmsync="http://127.0.0.1"]' }
    assert_response :success
    assert_xml_tag child: { tag: 'package', attributes: { name: 'appliance', project: 'home:tom:branches:home:adrian:IMAGES' } }

    # cleanup
    delete '/source/home:tom:branches:home:adrian:IMAGES'
    assert_response :success
    login_adrian
    delete '/source/home:adrian:IMAGES'
    assert_response :success
  end

  def test_fork_project
    login_adrian
    put '/source/home:adrian:IMAGES/_meta', params: "<project name='home:adrian:IMAGES'> <title/> <description/>
          <scmsync>http://localhost</scmsync>
          <repository name='images'>
            <arch>i586</arch>
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success

    # ensure we send a proper error message to osc
    raw_post '/source/home:adrian:IMAGES/appliance?cmd=commitfilelist', ' <directory></directory> '
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'not_found' }
    raw_put '/source/home:adrian:IMAGES/appliance/filename?rev=repository', '123'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'scmsync_read_only' }
    raw_post '/source/home:adrian:IMAGES/appliance?cmd=commitfilelist', ' <directory> <entry name="filename" md5="ba1f2511fc30423bdbb183fe33f3dd0f" /> </directory> '
    assert_response :success
    assert_xml_tag tag: 'directory', attributes: { error: 'missing' }
    post '/source/home:adrian:IMAGES/appliance', params: { cmd: 'commit' }
    assert_response :not_found

    login_tom
    post '/source/home:adrian:IMAGES/_project', params: { cmd: 'fork' }
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'missing_parameter' })

    # forking the project
    post '/source/home:adrian:IMAGES/_project', params: { cmd: 'fork', scmsync: 'http://127.0.0.1' }
    assert_response :success

    post '/source/home:adrian:IMAGES/_project', params: { cmd: 'fork', scmsync: 'http://127.0.0.1',
                                                          target_project: 'home:adrian:SOMEWHERE' }
    assert_response :forbidden

    get '/source/home:tom:branches:home:adrian:IMAGES/_project/_history'
    assert_response :success

    get '/source/home:tom:branches:home:adrian:IMAGES/_meta'
    assert_response :success
    assert_xml_tag(tag: 'repository', attributes: { name: 'images' })
    assert_xml_tag(tag: 'scmsync', content: 'http://127.0.0.1')
    assert_no_xml_tag(tag: 'path')

    get '/source/home:tom:branches:home:adrian:IMAGES/_project/_meta'
    assert_response :success
    assert_xml_tag(tag: 'scmsync', content: 'http://127.0.0.1')

    # cleanup
    delete '/source/home:tom:branches:home:adrian:IMAGES'
    assert_response :success
    login_adrian
    delete '/source/home:adrian:IMAGES'
    assert_response :success
  end

  def test_release_package
    login_adrian
    # define manual release target
    put '/source/home:adrian:RT/_meta', params: "<project name='home:adrian:RT'> <title/> <description/>
          <repository name='rt'>
            <arch>i586</arch>
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success

    run_scheduler('i586')
    run_scheduler('x86_64')

    login_Iggy
    get '/source/home:Iggy/_meta'
    assert_response :success
    orig_project_meta = @response.body
    doc = REXML::Document.new(@response.body)
    rt = doc.elements['/project/repository'].add_element 'releasetarget'
    rt.add_attribute(REXML::Attribute.new('project', 'home:adrian:RT'))
    rt.add_attribute(REXML::Attribute.new('repository', 'rt'))
    put '/source/home:Iggy/_meta', params: doc.to_s
    assert_response :success
    post '/source/home:Iggy/TestPack?cmd=branch&target_project=home:Iggy&target_package=TestPackBranch'
    assert_response :success
    get '/source/home:Iggy/TestPackBranch/_link'
    assert_response :success

    # try to release with incorrect trigger
    login_adrian
    post '/source/home:Iggy/TestPack?cmd=release'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'no_matching_release_target' }
    assert_match(/Trigger is not set to manual in any repository/, @response.body)

    # add correct trigger
    login_Iggy
    rt.add_attribute(REXML::Attribute.new('trigger', 'manual'))
    put '/source/home:Iggy/_meta', params: doc.to_s
    assert_response :success

    # this user is not allowed
    post '/source/home:Iggy/TestPack?cmd=release'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'cmd_execution_no_permission' }
    assert_match(/no permission to write in project home:adrian:RT/, @response.body)

    # release for real
    login_adrian
    post '/source/home:Iggy/TestPack?cmd=release'
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { code: 'ok' }
    post '/source/home:Iggy/TestPackBranch?cmd=release'
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { code: 'ok' }

    # process events
    run_scheduler('i586')

    # verify result
    get '/source/home:adrian:RT'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'TestPack' }
    assert_xml_tag tag: 'entry', attributes: { name: 'TestPackBranch' }

    # compare source with target repo
    get '/build/home:Iggy/10.2/i586/TestPack/'
    assert_response :success
    assert_xml_tag tag: 'binarylist', children: { count: 4 }
    assert_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-1.i586.rpm' }

    get '/build/home:adrian:RT/rt/i586/TestPack/'
    assert_response :success
    assert_xml_tag tag: 'binarylist', children: { count: 4 }
    assert_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-1.i586.rpm' }

    # link got expanded
    get '/source/home:adrian:RT/TestPackBranch/TestPack.spec'
    assert_response :success
    get '/source/home:adrian:RT/TestPackBranch/_link'
    assert_response :not_found

    # release for real with a defined release tag
    login_adrian
    post '/source/home:Iggy/TestPack?cmd=release&setrelease=Beta1'
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { code: 'ok' }

    # process events
    run_scheduler('i586')

    # verify result
    get '/source/home:adrian:RT'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'TestPack' }

    # compare source with target repo
    get '/build/home:Iggy/10.2/i586/TestPack/'
    assert_response :success
    assert_xml_tag tag: 'binarylist', children: { count: 4 }
    assert_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-1.i586.rpm' }

    get '/build/home:adrian:RT/rt/i586/TestPack/'
    assert_response :success
    assert_xml_tag tag: 'binarylist', children: { count: 4 }
    # binary got  renamed during release
    assert_no_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-1.i586.rpm' }
    assert_xml_tag tag: 'binary', attributes: { filename: 'package-1.0-Beta1.i586.rpm' }

    # cleanup
    login_Iggy
    put '/source/home:Iggy/_meta', params: orig_project_meta
    assert_response :success
    delete '/source/home:Iggy/TestPackBranch'
    assert_response :success
    login_adrian
    delete '/source/home:adrian:RT'
    assert_response :success
  end

  def test_release_multibuild_package
    login_adrian
    # define manual release target
    put '/source/home:adrian:RT/_meta', params: "<project name='home:adrian:RT'> <title/> <description/>
          <repository name='rt'>
            <arch>i586</arch>
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success

    run_scheduler('i586')
    run_scheduler('x86_64')

    login_Iggy
    get '/source/home:Iggy/_meta'
    assert_response :success
    orig_project_meta = @response.body
    doc = REXML::Document.new(@response.body)
    rt = doc.elements['/project/repository'].add_element 'releasetarget'
    rt.add_attribute(REXML::Attribute.new('project', 'home:adrian:RT'))
    rt.add_attribute(REXML::Attribute.new('repository', 'rt'))
    put '/source/home:Iggy/_meta', params: doc.to_s
    assert_response :success

    # add correct trigger
    login_Iggy
    rt.add_attribute(REXML::Attribute.new('trigger', 'manual'))
    put '/source/home:Iggy/_meta', params: doc.to_s
    assert_response :success

    # release for real
    login_adrian
    post '/source/home:Iggy/TestPack:package?cmd=release'
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { code: 'ok' }

    # process events
    run_scheduler('i586')

    # verify result
    get '/source/home:adrian:RT'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'TestPack' }

    # cleanup
    login_Iggy
    put '/source/home:Iggy/_meta', params: orig_project_meta
    assert_response :success
    login_adrian
    delete '/source/home:adrian:RT'
    assert_response :success
  end

  def test_manual_release_multibuild_package
    login_adrian
    # define manual release target
    put '/source/home:adrian:RT/_meta', params: "<project name='home:adrian:RT'> <title/> <description/>
          <repository name='rt'>
            <arch>i586</arch>
            <arch>x86_64</arch>
          </repository>
        </project>"
    assert_response :success

    run_scheduler('i586')
    run_scheduler('x86_64')

    # release for real
    login_adrian
    post '/source/home:Iggy/TestPack:package?cmd=release&target_project=home:adrian:RT&target_repository=rt&repository=10.2'
    assert_response :success
    assert_xml_tag tag: 'status', attributes: { code: 'ok' }

    # process events
    run_scheduler('i586')

    # verify result
    get '/source/home:adrian:RT'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'TestPack' }

    login_adrian
    delete '/source/home:adrian:RT'
    assert_response :success
  end

  def test_copy_package
    # fred has maintainer permissions in this single package of Iggys home
    # this is the osc way
    login_fred
    put '/source/home:Iggy/TestPack/filename', params: 'CONTENT'
    assert_response :success
    get '/source/home:Iggy/TestPack/_history'
    assert_response :success
    node = Xmlhash.parse(@response.body)
    revision = node.elements('revision').last['rev']

    # standard copy
    post '/source/home:fred/DELETE', params: { cmd: :copy, oproject: 'home:Iggy', opackage: 'TestPack' }
    assert_response :success
    get '/source/home:fred/DELETE/_history'
    assert_response :success
    assert_xml_tag tag: 'revisionlist', children: { count: 1 }

    # FIXME: this is not yet supported in backend
    if @ENABLE_BROKEN_TEST
      # copy with history
      post '/source/home:fred/DELETE', params: { cmd: :copy, oproject: 'home:Iggy', opackage: 'TestPack', withhistory: '1' }
      assert_response :success
      get '/source/home:fred/DELETE/_history'
      assert_response :success
      assert_xml_tag tag: 'revisionlist', children: { count: revision }
    end

    # cleanup
    delete '/source/home:fred/DELETE'
    assert_response :success
    delete '/source/home:Iggy/TestPack/filename'
    assert_response :success
  end

  def test_collectbuildenv
    login_Iggy
    post '/source/home:Iggy/TestPack?cmd=branch&target_project=home:Iggy&target_package=TestPackBranch'
    assert_response :success
    get '/source/home:Iggy/TestPackBranch/_link'
    assert_response :success

    post '/source/home:Iggy/TestPackBranch?cmd=collectbuildenv'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'missing_parameter' }

    post '/source/home:Iggy/TestPackBranch?cmd=collectbuildenv&oproject=home:Iggy&opackage=TestPack&comment=my+collectbuildenv'
    assert_response :success

    get '/source/home:Iggy/TestPackBranch/_history'
    assert_response :success
    assert_xml_tag tag: 'comment', content: 'my collectbuildenv'

    # global fallback _buildenv, contains always an error
    get '/source/home:Iggy/TestPackBranch/_buildenv'
    assert_response :success
    assert_xml_tag tag: 'error', content: 'no buildenv for this repo/arch'

    # specialized buildenv, does not exist in source
    get '/source/home:Iggy/TestPackBranch/_buildenv.10.2.i586'
    assert_response :success
    assert_xml_tag tag: 'error', content: '_buildenv missing in home:Iggy/10.2'
    get '/source/home:Iggy/TestPackBranch/_buildenv.10.2.x86_64'
    assert_response :success
    assert_xml_tag tag: 'error', content: '_buildenv missing in home:Iggy/10.2'

    # from BaseDistro project, we build against
    post '/source/home:Iggy/TestPackBranch?cmd=collectbuildenv&oproject=BaseDistro&opackage=pack1&comment=my+collectbuildenv'
    assert_response :success
    # global fallback _buildenv, contains always an error
    get '/source/home:Iggy/TestPackBranch/_buildenv'
    assert_response :success
    assert_xml_tag tag: 'error', content: 'no buildenv for this repo/arch'

    # specialized buildenv, contains the right repo name
    get '/source/home:Iggy/TestPackBranch/_buildenv.10.2.i586'
    assert_response :success
    assert_xml_tag tag: 'error', content: '_buildenv missing in BaseDistro/BaseDistro_repo'

    # cleanup
    delete '/source/home:Iggy/TestPackBranch'
    assert_response :success
  end

  def test_copy_project
    # NOTE: copy tests for release projects are part of maintenance tests
    login_fred
    get '/source/home:Iggy/_meta'
    assert_response :success
    assert_xml_tag tag: 'person', attributes: { userid: 'Iggy', role: 'maintainer' }
    orig = @response.body
    post '/source/home:fred:COPY', params: { cmd: :copy, oproject: 'home:Iggy' }
    assert_response :success
    get '/source/home:fred:COPY/_meta'
    assert_response :success
    assert_no_xml_tag tag: 'person', attributes: { userid: 'Iggy' }
    copy = @response.body
    # almost everything must be identical
    orig = orig.gsub(/project name=.*/, 'project') # make project name identical
    copy = copy.gsub(/project name=.*/, 'project')
    orig = orig.gsub(/.*<person.*\n/, '') # remove all person lines, they have to differ
    copy = copy.gsub(/.*<person.*\n/, '')
    assert_equal copy, orig

    # permissions
    # create new project is not allowed
    post '/source/TEMPCOPY', params: { cmd: :copy, oproject: 'home:Iggy', nodelay: '1' }
    assert_response :forbidden
    assert_xml_tag(tag: 'status', attributes: { code: 'cmd_execution_no_permission' })
    login_king
    put '/source/TEMPCOPY/_meta', params: '<project name="TEMPCOPY"> <title/> <description/> <person role="maintainer" userid="fred"/> </project>'
    assert_response :success
    # copy into existing project is allowed
    login_fred
    post '/source/TEMPCOPY', params: { cmd: :copy, oproject: 'home:Iggy' }
    assert_response :success

    # cleanup
    delete '/source/home:fred:COPY'
    assert_response :success
    delete '/source/TEMPCOPY'
    assert_response :success
  end

  def test_source_commits
    login_tom
    post '/source/home:Iggy/TestPack', params: { cmd: 'commitfilelist' }
    assert_response :forbidden
    put '/source/home:Iggy/TestPack/filename', params: 'CONTENT'
    assert_response :forbidden

    # fred has maintainer permissions in this single package of Iggys home
    # this is the osc way
    login_fred
    delete '/source/home:Iggy/TestPack/filename' # in case other tests created it
    put '/source/home:Iggy/TestPack/filename?rev=repository', params: 'CONTENT'
    assert_response :success
    get '/source/home:Iggy/TestPack/filename'
    assert_response :not_found
    get '/source/home:Iggy/TestPack/_history?limit=1'
    assert_response :success
    assert_xml_tag tag: 'revisionlist', children: { count: 1 }
    get '/source/home:Iggy/TestPack/_history'
    assert_response :success
    assert_no_xml_tag tag: 'revisionlist', children: { count: 1 }
    node = Xmlhash.parse(@response.body)
    revision = node.elements('revision').last['rev']
    revision = revision.to_i + 1
    raw_post '/source/home:Iggy/TestPack?cmd=commitfilelist', ' <directory> <entry name="filename" md5="45685e95985e20822fb2538a522a5ccf" /> </directory> '
    assert_response :success
    get '/source/home:Iggy/TestPack/filename'
    assert_response :success
    get '/source/home:Iggy/TestPack/_history'
    assert_response :success
    assert_xml_tag(parent: { tag: 'revision', attributes: { rev: revision.to_s }, content: nil }, tag: 'user', content: 'fred')
    assert_xml_tag(parent: { tag: 'revision', attributes: { rev: revision.to_s }, content: nil }, tag: 'srcmd5')

    # delete file with commit
    delete '/source/home:Iggy/TestPack/filename'
    assert_response :success
    revision = revision.to_i + 1
    get '/source/home:Iggy/TestPack/filename'
    assert_response :not_found

    # this is the future webui way
    login_fred
    put '/source/home:Iggy/TestPack/filename?rev=upload', params: 'CONTENT'
    assert_response :success
    get '/source/home:Iggy/TestPack/filename'
    assert_response :success
    get '/source/home:Iggy/TestPack/filename?rev=latest'
    assert_response :not_found
    get '/source/home:Iggy/TestPack/_history'
    assert_response :success
    revision = revision.to_i + 1
    assert_no_xml_tag(tag: 'revision', attributes: { rev: revision.to_s })
    post '/source/home:Iggy/TestPack?cmd=commit'
    assert_response :success
    get '/source/home:Iggy/TestPack/filename?rev=latest'
    assert_response :success
    get '/source/home:Iggy/TestPack/_history'
    assert_response :success
    assert_xml_tag(parent: { tag: 'revision', attributes: { rev: revision.to_s }, content: nil }, tag: 'user', content: 'fred')
    assert_xml_tag(parent: { tag: 'revision', attributes: { rev: revision.to_s }, content: nil }, tag: 'srcmd5')

    # test deleteuploadrev
    put '/source/home:Iggy/TestPack/anotherfilename?rev=upload', params: 'CONTENT'
    assert_response :success
    get '/source/home:Iggy/TestPack/anotherfilename'
    assert_response :success
    get '/source/home:Iggy/TestPack/anotherfilename?rev=latest'
    assert_response :not_found
    post '/source/home:Iggy/TestPack?cmd=deleteuploadrev'
    assert_response :success
    get '/source/home:Iggy/TestPack/anotherfilename'
    assert_response :not_found

    #
    # Test commits to special packages
    #
    login_Iggy
    # _product must be created
    put '/source/home:Iggy/_product/_meta', params: "<package project='home:Iggy' name='_product'> <title/> <description/> </package>"
    assert_response :success
    put '/source/home:Iggy/_product/filename?rev=repository', params: 'CONTENT'
    assert_response :success
    raw_post '/source/home:Iggy/_product?cmd=commitfilelist', ' <directory> <entry name="filename" md5="45685e95985e20822fb2538a522a5ccf" /> </directory> '
    assert_response :success
    get '/source/home:Iggy/_product/filename'
    assert_response :success
    put '/source/home:Iggy/_product/filename2', params: 'CONTENT'
    assert_response :success
    get '/source/home:Iggy/_product/filename2'
    assert_response :success

    # _pattern exists always
    put '/source/home:Iggy/_pattern/filename', params: 'CONTENT'
    assert_response :bad_request # illegal content
    put '/source/home:Iggy/_pattern/filename?rev=repository', params: load_backend_file('pattern/digiKam.xml')
    assert_response :success
    raw_post '/source/home:Iggy/_pattern?cmd=commitfilelist', ' <directory> <entry name="filename" md5="c5fadc30cd4c7d45bd3ce053b2751ec2" /> </directory> '
    assert_response :success
    get '/source/home:Iggy/_pattern/filename'
    assert_response :success
    put '/source/home:Iggy/_pattern/filename2', params: load_backend_file('pattern/digiKam.xml')
    assert_response :success
    get '/source/home:Iggy/_pattern/filename2'
    assert_response :success

    # _project exists always
    put '/source/home:Iggy/_project/filename?rev=repository', params: 'CONTENT'
    assert_response :success
    raw_post '/source/home:Iggy/_project?cmd=commitfilelist', ' <directory> <entry name="filename" md5="45685e95985e20822fb2538a522a5ccf" /> </directory> '
    assert_response :success
    get '/source/home:Iggy/_project/filename'
    assert_response :success
    put '/source/home:Iggy/_project/filename2', params: 'CONTENT'
    assert_response :success
    get '/source/home:Iggy/_project/filename2'
    assert_response :success

    # restore
    delete '/source/home:Iggy/_product'
    assert_response :success
    delete '/source/home:Iggy/_pattern'
    assert_response :success
    raw_put '/source/home:Iggy/TestPack/TestPack.spec', load_backend_file('source/home:Iggy/TestPack/TestPack.spec')
    assert_response :success
    put('/source/home:Iggy/TestPack/myfile', params: 'DummyContent')
    assert_response :success
    delete '/source/home:Iggy/TestPack/filename'
    assert_response :success
  end

  def test_branch_and_merge_changes
    login_Iggy
    post '/source/kde4/kdelibs?cmd=branch&target_project=home:Iggy&target_package=kdelibs_upstream'
    assert_response :success
    put '/source/home:Iggy/kdelibs_upstream/kdelibs.changes', params: File.read("#{Rails.root}/test/fixtures/backend/source/kde4/kdelibs/kdelibs.changes")
    post '/source/home:Iggy/kdelibs_upstream?cmd=branch&target_project=home:Iggy&target_package=kdelibs_branch'
    assert_response :success
    # apply conflicting changes for diff3 ... but not for our changes merge tool
    put '/source/home:Iggy/kdelibs_branch/kdelibs.changes', params: File.read("#{Rails.root}/test/fixtures/backend/source/kde4/kdelibs/kdelibs.changes.branch")
    put '/source/home:Iggy/kdelibs_upstream/kdelibs.changes', params: File.read("#{Rails.root}/test/fixtures/backend/source/kde4/kdelibs/kdelibs.changes.new")

    # merge is working?
    get '/source/home:Iggy/kdelibs_branch?expand=1'
    assert_response :success
    get '/source/home:Iggy/kdelibs_branch/kdelibs.changes?expand=1'
    assert_response :success
    assert_equal File.read("#{Rails.root}/test/fixtures/backend/source/kde4/kdelibs/kdelibs.changes.merged"), @response.body

    # cleanup
    delete '/source/home:Iggy/kdelibs_branch'
    assert_response :success
    delete '/source/home:Iggy/kdelibs_upstream'
    assert_response :success
  end

  def test_block_branching
    login_king
    post '/source/kde4/kdelibs/_attribute', params: "
        <attributes><attribute namespace='OBS' name='RejectBranch'>
          <value>Please work instead elsewhere</value>
        </attribute></attributes>"
    assert_response :success

    login_Iggy
    post '/source/kde4/kdelibs?cmd=branch&ignoredevel=1'
    assert_response :forbidden
    assert_match 'Please work instead elsewhere', @response.body

    # cleanup
    login_king
    delete '/source/kde4/kdelibs/_attribute/OBS:RejectBranch'
    assert_response :success
  end

  def test_list_of_linking_instances
    login_tom

    # list all linking projects
    post '/source/BaseDistro2.0', params: { cmd: 'showlinked' }
    assert_response :success
    assert_xml_tag(tag: 'project', attributes: { name: 'BaseDistro2.0:LinkedUpdateProject' }, content: nil)

    # list all linking packages with a local link
    post '/source/BaseDistro/pack2', params: { cmd: 'showlinked' }
    assert_response :success
    assert_xml_tag(tag: 'package', attributes: { project: 'BaseDistro:Update', name: 'pack2' }, content: nil)

    # list all linking packages, base package is a package on a remote OBS instance
    # FIXME: support for this search is possible, but not yet implemented
    #    post "/source/RemoteInstance:BaseDistro/pack", :cmd => "showlinked"
    #    assert_response :success
    #    assert_xml_tag( :tag => "package", :attributes => { :project => "BaseDistro:Update", :name => "pack2" }, :content => nil )
  end

  def test_create_links
    login_king
    put url_for(controller: :source_project_meta, action: :update, project: 'TEMPORARY'), params: '<project name="TEMPORARY"> <title/> <description/> <person role="maintainer" userid="fred"/> </project>'
    assert_response :ok
    # create packages via user without any special roles
    login_fred
    get url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'temporary')
    assert_response :not_found
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'temporary'), params: '<package project="kde4" name="temporary"> <title/> <description/> </package>'
    assert_response :ok
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })
    put url_for(controller: :source_package_meta, action: :update, project: 'kde4', package: 'temporary2'), params: '<package project="kde4" name="temporary2"> <title/> <description/> </package>'
    assert_response :ok
    assert_xml_tag(tag: 'status', attributes: { code: 'ok' })
    put '/source/kde4/temporary/file_in_linked_package', params: 'FILE CONTENT'
    assert_response :ok
    put url_for(controller: :source_package_meta, action: :update, project: 'TEMPORARY', package: 'temporary2'), params: '<package project="TEMPORARY" name="temporary2"> <title/> <description/> </package>'
    assert_response :ok

    url = '/source/kde4/temporary/_link'
    url2 = '/source/kde4/temporary2/_link'
    url3 = '/source/TEMPORARY/temporary2/_link'

    # illegal targets
    put url, params: '<link project="notexisting" />'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }
    put url, params: '<link project="kde4" package="notexiting" />'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_package' }

    # not existing link target, but ignore it
    put url, params: '<link project="kde4" package="notexiting" missingok="true" />'
    assert_response :success
    put url, params: '<link project="BaseDistro" package="pack1" missingok="true" />'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'not_missing' }

    # working local link
    put url, params: '<link project="BaseDistro" package="pack1" />'
    assert_response :success
    put url2, params: '<link package="temporary" />'
    assert_response :success
    put url3, params: '<link project="kde4" />'
    assert_response :success

    # working link to package via project link
    put url, params: '<link project="BaseDistro2.0:LinkedUpdateProject" package="pack2" />'
    assert_response :success
    # working link to remote package
    put url, params: '<link project="RemoteInstance:BaseDistro" package="pack1" />'
    assert_response :success
    put url, params: '<link project="RemoteInstance:BaseDistro2.0:LinkedUpdateProject" package="pack2" />'
    assert_response :success
    # working link to remote project link
    put url, params: '<link project="UseRemoteInstance" package="pack2" />'
    assert_response :success

    # check backend functionality
    get '/source/kde4/temporary'
    assert_response :success
    assert_no_xml_tag(tag: 'entry', attributes: { name: 'my_file' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'file_in_linked_package' })
    assert_xml_tag(tag: 'entry', attributes: { name: '_link' })
    assert_xml_tag(tag: 'linkinfo', attributes: { project: 'UseRemoteInstance', package: 'pack2',
                                                  srcmd5: 'd3e3fafcc29140ff418220a649df8070', xsrcmd5: '3481fc5f1445a65a2d463b8adf26d3a9', lsrcmd5: 'e6a8595663acb2095c62824bf457142c' })
    get '/source/kde4/temporary2?expand=1'
    assert_response :success
    assert_xml_tag(tag: 'entry', attributes: { name: 'package.spec' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'file_in_linked_package' })
    assert_xml_tag(tag: 'linkinfo', attributes: { project: 'kde4', package: 'temporary' })
    assert_no_xml_tag(tag: 'entry', attributes: { name: '_link' })
    get '/source/TEMPORARY/temporary2?expand=1'
    assert_response :success
    assert_xml_tag(tag: 'entry', attributes: { name: 'package.spec' })
    assert_xml_tag(tag: 'entry', attributes: { name: 'file_in_linked_package' })
    assert_xml_tag(tag: 'linkinfo', attributes: { project: 'kde4', package: 'temporary2' })
    assert_no_xml_tag(tag: 'entry', attributes: { name: '_link' })

    # cleanup
    delete '/source/kde4/temporary'
    assert_response :success
    delete '/source/kde4/temporary2'
    assert_response :success
    login_king
    delete '/source/TEMPORARY'
    assert_response :success
  end

  def test_parse_channel_file
    login_Iggy
    put '/source/home:Iggy/TestChannel/_meta', params: "<package project='home:Iggy' name='TestChannel'> <title/> <description/> </package>"
    assert_response :success

    put '/source/home:Iggy/TestChannel/_channel', params: '<channel/>' # binaries and binary element is required
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'validation_failed' }

    put '/source/home:Iggy/TestChannel/_channel', params: '<?xml version="1.0" encoding="UTF-8"?>
	<channel>
	  <target project="BaseDistro" repository="Invalid" />
	  <binaries>
	    <binary name="krabber"/>
	  </binaries>
	</channel>'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_repository' }

    put '/source/home:Iggy/TestChannel/_channel', params: '<?xml version="1.0" encoding="UTF-8"?>
	<channel>
	  <target project="Invalid" repository="Invalid" />
	  <binaries>
	    <binary name="krabber"/>
	  </binaries>
	</channel>'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_project' }

    put '/source/home:Iggy/TestChannel/_channel', params: '<?xml version="1.0" encoding="UTF-8"?>
	<channel>
	  <binaries project="BaseDistro" repository="BaseDistro_repo" arch="does_not_exist">
	    <binary name="glibc-devel" binaryarch="noarch" package="pack1" project="BaseDistro" repository="BaseDistro_repo" arch="i586"/>
	  </binaries>
	</channel>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'validation_failed' }

    put '/source/home:Iggy/TestChannel/_channel', params: '<?xml version="1.0" encoding="UTF-8"?>
	<channel>
	  <binaries project="BaseDistro" repository="BaseDistro_repo" arch="i586">
	    <binary name="glibc-devel" package="INVALID" project="BaseDistro"/>
	  </binaries>
	</channel>'
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'unknown_package' }

    put '/source/home:Iggy/TestChannel/_channel', params: '<?xml version="1.0" encoding="UTF-8"?>
	<channel>
	  <binaries>
	    <binary />
	  </binaries>
	</channel>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'validation_failed' }

    put '/source/home:Iggy/TestChannel/_channel', params: '<?xml version="1.0" encoding="UTF-8"?>
	<channel>
	  <product project="BaseDistro" name="simple" />
	  <target project="BaseDistro" repository="BaseDistro_repo" />
	  <binaries project="BaseDistro" repository="BaseDistro_repo" arch="i586">
	    <binary name="glibc-devel" binaryarch="noarch" package="pack1" project="BaseDistro" repository="BaseDistro_repo" arch="i586"/>
	    <binary name="glibc" />
	  </binaries>
	</channel>'
    assert_response :success

    # check data in database
    c = Package.find_by_project_and_name('home:Iggy', 'TestChannel').channels.first
    assert_match c.channel_targets.first.repository.project.name, 'BaseDistro'
    assert_match c.channel_targets.first.repository.name, 'BaseDistro_repo'

    b = c.channel_binary_lists.first
    assert_match b.project.name, 'BaseDistro'
    assert_match b.repository.project.name, 'BaseDistro'
    assert_match b.repository.name, 'BaseDistro_repo'

    b = b.channel_binaries.first
    assert_match b.name, 'glibc-devel'
    assert_match b.binaryarch, 'noarch'
    assert_match b.package, 'pack1'
    assert_match b.project.name, 'BaseDistro'
    assert_match b.repository.project.name, 'BaseDistro'
    assert_match b.repository.name, 'BaseDistro_repo'

    # check search interface
    get '/search/channel/binary?match=@project="home:Iggy"+and+@name="glibc-devel"'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '1' }
    assert_xml_tag parent: { tag: 'channel', attributes: { project: 'home:Iggy', package: 'TestChannel' } },
                   tag: 'binary', attributes: { package: 'pack1', name: 'glibc-devel', binaryarch: 'noarch' }
    assert_xml_tag parent: { tag: 'channel', attributes: { project: 'home:Iggy', package: 'TestChannel' } },
                   tag: 'target', attributes: { project: 'BaseDistro', repository: 'BaseDistro_repo' }
    get '/search/channel/binary?match=@package="pack1"'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '1' }
    get '/search/channel/binary?match=@binaryarch="noarch"'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '1' }
    # no product, but no crash either. More checks are in channel_maintenance test case
    get '/search/channel/binary?match=updatefor[@project="not_defined"+and+@product="missing"]'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '0' }
    # simple short form test
    get '/search/channel/binary/id?match=@name="glibc-devel"'
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '1' }
    assert_xml_tag tag: 'channel', attributes: { project: 'home:Iggy', package: 'TestChannel' }
    assert_xml_tag tag: 'binary', attributes: { package: 'pack1', name: 'glibc-devel', binaryarch: 'noarch' }
    assert_no_xml_tag tag: 'target'

    # cleanup
    delete '/source/home:Iggy/TestChannel'
    assert_response :success
  end

  def test_create_project_with_hostsystem
    login_tom
    # testing with overlap of one repo
    raw_put '/source/home:tom:temporary/_meta',
            '<project name="home:tom:temporary"> <title/> <description/>
               <repository name="cross_compile_with_sysroot">
                 <hostsystem project="BaseDistro2.0" repository="BaseDistro2_repo" />
                 <hostsystem project="BaseDistro" repository="BaseDistro_repo" />
                 <path project="BaseDistro2.0:LinkedUpdateProject" repository="BaseDistro2LinkedUpdateProject_repo" />
                 <path project="BaseDistro2.0" repository="BaseDistro2_repo" />
               </repository>
             </project>'
    assert_response :success

    get '/source/home:tom:temporary/_meta'
    assert_response :success
    assert_xml_tag tag: 'hostsystem', attributes: { project: 'BaseDistro2.0', repository: 'BaseDistro2_repo' }
    assert_xml_tag tag: 'hostsystem', attributes: { project: 'BaseDistro', repository: 'BaseDistro_repo' }
    assert_xml_tag tag: 'path', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject', repository: 'BaseDistro2LinkedUpdateProject_repo' }
    assert_xml_tag tag: 'path', attributes: { project: 'BaseDistro2.0', repository: 'BaseDistro2_repo' }

    delete '/source/home:tom:temporary'
    assert_response :success
  end

  def test_create_project_with_invalid_repository_reference
    login_tom
    put url_for(controller: :source_project_meta, action: :update, project: 'home:tom:temporary'), params: '<project name="home:tom:temporary"> <title/> <description/>
           <repository name="me" />
         </project>'
    assert_response :success
    # self reference
    put url_for(controller: :source_project_meta, action: :update, project: 'home:tom:temporary'), params: '<project name="home:tom:temporary"> <title/> <description/>
           <repository name="me">
             <path project="home:tom:temporary" repository="me" />
           </repository>
         </project>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'project_save_error' }
    assert_match(/Using same repository as path element is not allowed/, @response.body)
    put url_for(controller: :source_project_meta, action: :update, project: 'home:tom:temporary'), params: '<project name="home:tom:temporary"> <title/> <description/>
           <repository name="me">
             <hostsystem project="home:tom:temporary" repository="me" />
           </repository>
         </project>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'project_save_error' }
    assert_match(/Using same repository as hostsystem element is not allowed/, @response.body)
    # not existing repo
    put url_for(controller: :source_project_meta, action: :update, project: 'home:tom:temporary'), params: '<project name="home:tom:temporary"> <title/> <description/>
           <repository name="me">
             <path project="home:tom:temporary" repository="DOESNOTEXIST" />
           </repository>
         </project>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'project_save_error' }
    assert_match(/Cannot find repository/, @response.body)
    put url_for(controller: :source_project_meta, action: :update, project: 'home:tom:temporary'), params: '<project name="home:tom:temporary"> <title/> <description/>
           <repository name="me">
             <hostsystem project="home:tom:temporary" repository="DOESNOTEXIST" />
           </repository>
         </project>'
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'project_save_error' }
    assert_match(/Unknown hostsystem repository/, @response.body)

    delete '/source/home:tom:temporary'
    assert_response :success
  end

  def test_use_project_link_as_non_maintainer
    login_tom
    put url_for(controller: :source_project_meta, action: :update, project: 'home:tom:temporary'), params: '<project name="home:tom:temporary"> <title/> <description/> <link project="kde4" /> </project>'
    assert_response :success
    get '/source/home:tom:temporary'
    assert_response :success
    get '/source/home:tom:temporary/kdelibs'
    assert_response :success
    get '/source/home:tom:temporary/kdelibs/_history'
    assert_response :success
    delete '/source/home:tom:temporary/kdelibs'
    assert_response :not_found
    post '/source/home:tom:temporary/kdelibs', params: { cmd: :copy, oproject: 'home:tom:temporary', opackage: 'kdelibs' }
    assert_response :success
    get '/source/home:tom:temporary/kdelibs/_meta'
    meta = @response.body
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { project: 'home:tom:temporary' }
    delete '/source/home:tom:temporary/kdelibs'
    assert_response :success
    delete '/source/home:tom:temporary/kdelibs'
    assert_response :not_found

    # check if package creation is doing the right thing
    put '/source/home:tom:temporary/kdelibs/_meta', params: meta.dup
    assert_response :success
    delete '/source/home:tom:temporary/kdelibs'
    assert_response :success
    delete '/source/home:tom:temporary/kdelibs'
    assert_response :not_found

    # cleanup
    delete '/source/home:tom:temporary'
    assert_response :success
  end

  def test_freeze_project_link
    login_tom

    # create a project link
    raw_put '/source/home:tom:LINK_TEST/_meta',
            '<project name="home:tom:LINK_TEST"><title/><description/><link project="BaseDistro2.0:LinkedUpdateProject"/></project>'
    assert_response :success

    login_Iggy
    post '/source/home:tom:LINK_TEST?cmd=freezelink'
    assert_response :forbidden

    login_tom
    get '/source/home:tom:LINK_TEST/_project/_frozenlinks?meta=1'
    assert_response :not_found

    post '/source/home:tom:LINK_TEST?cmd=freezelink'
    assert_response :success

    get '/source/home:tom:LINK_TEST/_project/_frozenlinks?meta=1'
    assert_response :success
    assert_xml_tag tag: 'frozenlink', attributes: { project: 'BaseDistro2.0:LinkedUpdateProject' }
    assert_xml_tag tag: 'package', attributes: { name: 'pack2' }
    assert_xml_tag tag: 'package', attributes: { name: 'pack2.linked' }
    assert_xml_tag tag: 'package', attributes: { name: 'pack_local' }

    # cleanup
    delete '/source/home:tom:LINK_TEST'
    assert_response :success
  end

  def test_delete_and_undelete_permissions
    delete '/source/kde4/kdelibs'
    assert_response :unauthorized
    delete '/source/kde4'
    assert_response :unauthorized

    login_tom
    delete '/source/kde4/kdelibs'
    assert_response :forbidden
    delete '/source/kde4'
    assert_response :forbidden

    login_adrian
    delete '/source/kde4/kdelibs'
    assert_response :success
    delete '/source/kde4'
    assert_response :success

    login_tom
    post '/source/kde4', params: { cmd: :undelete }
    assert_response :forbidden

    login_adrian
    post '/source/kde4', params: { cmd: :undelete }
    assert_response :forbidden

    login_king
    post '/source/kde4', params: { cmd: :undelete }
    assert_response :success

    login_tom
    post '/source/kde4/kdelibs', params: { cmd: :undelete }
    assert_response :forbidden

    login_adrian
    post '/source/kde4/kdelibs', params: { cmd: :undelete }
    assert_response :success
  end

  def test_branch_creating_project
    post '/source/home:Iggy/TestPack', params: { cmd: :branch }
    assert_response :unauthorized
    assert_xml_tag tag: 'status', attributes: { code: 'authentication_required' }
    Configuration.stubs(:anonymous).returns(false)
    # still 401 and not 403 (or it breaks osc login)
    post '/source/home:Iggy/TestPack', params: { cmd: :branch }
    assert_response :unauthorized
    assert_xml_tag tag: 'status', attributes: { code: 'authentication_required' }

    prepare_request_with_user('fredlibs', 'buildservice')
    # ensure he has no home project
    get '/source/home:fredlibs'
    assert_response :not_found

    # Create public project, but api config is changed to make it closed
    Configuration.stubs(:allow_user_to_create_home_project).returns(false)
    Configuration.stubs(:anonymous).returns(true)
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, dryrun: '1' }
    assert_response :success
    post '/source/home:Iggy/TestPack', params: { cmd: :branch }
    assert_response :forbidden

    # create home and try again
    login_king
    put '/source/home:fredlibs/_meta', params: "<project name='home:fredlibs'><title/><description/> <person role='maintainer' userid='fredlibs'/> </project>"
    assert_response :success

    prepare_request_with_user('fredlibs', 'buildservice')
    post '/source/home:Iggy/TestPack', params: { cmd: :branch }
    assert_response :success

    # auto delete attribute got created
    get '/source/home:fredlibs:branches:home:Iggy/_attribute'
    assert_response :success
    assert_xml_tag tag: 'value', parent: { tag: 'attribute', attributes: { name: 'AutoCleanup', namespace: 'OBS' } }

    # in future
    travel(10.days) do
      User.session = User.find_by_login('fredlibs')
      ProjectCreateAutoCleanupRequestsJob.perform_now
      User.session = nil
    end
    # validate request
    br = BsRequest.last
    assert_equal br.state, :new
    assert_equal br.bs_request_actions.first.type, 'delete'
    assert_equal br.bs_request_actions.first.target_project, 'home:fredlibs:branches:home:Iggy'
    assert_not_nil br.accept_at
    # second run shall not open another request
    # in future
    travel(12.days) do
      ProjectCreateAutoCleanupRequestsJob.perform_now
    end
    assert_equal br, BsRequest.last

    # cleanup and try again with defaults
    Configuration.stubs(:allow_user_to_create_home_project).returns(true)
    delete '/source/home:fredlibs:branches:home:Iggy'
    assert_response :success
    post '/source/home:Iggy/TestPack', params: { cmd: :branch }
    assert_response :success

    # cleanup
    delete '/source/home:fredlibs:branches:home:Iggy'
    assert_response :success
    delete '/source/home:fredlibs'
    assert_response :success
  end

  def test_branch_package_delete_and_undelete
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, target_project: 'home:coolo:test' }
    assert_response :unauthorized
    assert_xml_tag tag: 'status', attributes: { code: 'authentication_required' }
    prepare_request_with_user('fredlibs', 'buildservice')
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, target_project: 'NotExisting' }
    assert_response :forbidden
    assert_match(/no permission to create project/, @response.body)
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, target_project: 'home:coolo:test' }
    assert_response :forbidden
    assert_match(/no permission to/, @response.body)
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, target_project: 'home:coolo:test', force: '1' }
    assert_response :forbidden
    assert_match(/no permission to/, @response.body)
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, target_project: 'home:coolo:test', dryrun: '1' }
    assert_response :success
    assert_xml_tag tag: 'package', attributes: { package: 'TestPack', project: 'home:Iggy' },
                   child: { tag: 'target', attributes: { package: 'TestPack', project: 'home:coolo:test' } }

    login_tom
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, target_project: 'home:coolo:test' }
    assert_response :success
    get '/source/home:coolo:test/TestPack/_meta'
    assert_response :success

    # branch again
    get '/source/home:coolo:test/_meta'
    assert_response :success
    oldmeta = @response.body
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, target_project: 'home:coolo:test' }
    assert_response :bad_request
    assert_match(/branch target package already exists/, @response.body)
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, target_project: 'home:coolo:test', force: '1' }
    assert_response :success
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, target_project: 'home:coolo:test', force: '1', rev: '1' }
    assert_response :success
    post '/source/home:Iggy/TestPack', params: { cmd: :branch, target_project: 'home:coolo:test', force: '1', rev: '42424242' }
    assert_response :bad_request
    assert_match(/no such revision/, @response.body)
    # project meta must be untouched
    get '/source/home:coolo:test/_meta'
    assert_response :success
    assert_equal oldmeta, @response.body
    # FIXME: do a real commit and branch afterwards

    # now with a new project
    post '/source/home:Iggy/TestPack', params: { cmd: :branch }
    assert_response :success

    get '/source/home:tom:branches:home:Iggy/TestPack/_meta'
    assert_response :success

    get '/source/home:tom:branches:home:Iggy/_meta'
    assert_equal({ 'name' => '10.2', 'path' => { 'project' => 'home:Iggy', 'repository' => '10.2' }, 'arch' => %w[i586 x86_64] }, Xmlhash.parse(@response.body)['repository'])

    # check source link
    get '/source/home:tom:branches:home:Iggy/TestPack/_link'
    assert_response :success
    ret = Xmlhash.parse(@response.body)
    assert_equal 'home:Iggy', ret['project']
    assert_nil ret['package']
    assert_not_nil ret['baserev']
    assert_not_nil ret['patches']
    assert_not_nil ret['patches']['branch']

    # Branch a package with a defined devel package
    post '/source/kde4/kdelibs', params: { cmd: :branch }
    assert_response :success
    assert_xml_tag(tag: 'data', attributes: { name: 'targetproject' }, content: 'home:tom:branches:home:coolo:test')
    assert_xml_tag(tag: 'data', attributes: { name: 'targetpackage' }, content: 'kdelibs_DEVEL_package')
    assert_xml_tag(tag: 'data', attributes: { name: 'sourceproject' }, content: 'home:coolo:test')
    assert_xml_tag(tag: 'data', attributes: { name: 'sourcepackage' }, content: 'kdelibs_DEVEL_package')

    # delete package
    reset_auth
    delete '/source/home:tom:branches:home:Iggy/TestPack'
    assert_response :unauthorized

    login_tom
    delete '/source/home:tom:branches:home:Iggy/TestPack'
    assert_response :success

    get '/source/home:tom:branches:home:Iggy/TestPack'
    assert_response :not_found
    get '/source/home:tom:branches:home:Iggy/TestPack/_meta'
    assert_response :not_found

    # undelete package
    post '/source/home:tom:branches:home:Iggy/TestPack', params: { cmd: :undelete }
    assert_response :success

    # content got restored ?
    get '/source/home:tom:branches:home:Iggy/TestPack'
    assert_response :success
    get '/source/home:tom:branches:home:Iggy/TestPack/_meta'
    assert_response :success
    get '/source/home:tom:branches:home:Iggy/TestPack/_link'
    assert_response :success

    # undelete package again
    post '/source/home:tom:branches:home:Iggy/TestPack', params: { cmd: :undelete }
    assert_response :bad_request # already exists

    # cleanup
    login_king
    delete '/source/home:tom:branches:home:Iggy'
    assert_response :success
    delete '/source/home:tom:branches:home:coolo:test'
    assert_response :success
    delete '/source/home:coolo:test/TestPack'
    assert_response :success
  end

  def test_package_set_flag
    login_Iggy

    get '/source/home:Iggy/TestPack/_meta'
    assert_response :success
    original = @response.body

    post '/source/home:unknown/Nothere?cmd=set_flag&repository=10.2&arch=i586&flag=build'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)

    post '/source/home:Iggy/Nothere?cmd=set_flag&repository=10.2&arch=i586&flag=build'
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)

    post '/source/home:Iggy/Nothere?cmd=set_flag&repository=10.2&arch=i586&flag=build&status=enable'
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)

    post '/source/home:Iggy/TestPack?cmd=set_flag&repository=10.2&arch=i586&flag=build&status=anything'
    assert_response :bad_request
    assert_match(/Error: unknown status for flag 'anything'/, @response.body)

    post '/source/home:Iggy/TestPack?cmd=set_flag&repository=10.2&arch=i586&flag=shine&status=enable'
    assert_response :bad_request
    assert_match(/Error: unknown flag type 'shine' not found./, @response.body)

    get '/source/home:Iggy/TestPack/_meta'
    assert_response :success
    # so far noting should have changed
    assert_equal original, @response.body

    post '/source/kde4/kdelibs?cmd=set_flag&repository=10.7&arch=i586&flag=build&status=enable'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'cmd_execution_no_permission' }

    post '/source/home:Iggy/TestPack?cmd=set_flag&repository=10.7&arch=i586&flag=build&status=enable'
    assert_response :success # actually I consider forbidding repositories not existent

    get '/source/home:Iggy/TestPack/_meta'
    assert_not_equal original, @response.body
  end

  def test_project_set_flag
    login_Iggy

    get '/source/home:Iggy/_meta'
    assert_response :success
    original = @response.body

    post '/source/home:unknown?cmd=set_flag&repository=10.2&arch=i586&flag=build'
    assert_response :not_found

    post '/source/home:Iggy?cmd=set_flag&repository=10.2&arch=i586&flag=build'
    assert_response :bad_request
    assert_match(/Required Parameter status missing/, @response.body)

    post '/source/home:Iggy?cmd=set_flag&repository=10.2&arch=i586&flag=build&status=anything'
    assert_response :bad_request
    assert_match(/Error: unknown status for flag 'anything'/, @response.body)

    post '/source/home:Iggy?cmd=set_flag&repository=10.2&arch=i586&flag=shine&status=enable'
    assert_response :bad_request
    assert_match(/Error: unknown flag type 'shine' not found./, @response.body)

    get '/source/home:Iggy/_meta'
    assert_response :success
    # so far noting should have changed
    assert_equal original, @response.body

    post '/source/kde4?cmd=set_flag&repository=10.7&arch=i586&flag=build&status=enable'
    assert_response :forbidden
    assert_match(/no permission to execute command/, @response.body)

    post '/source/home:Iggy?cmd=set_flag&repository=10.7&arch=i586&flag=build&status=enable'
    assert_response :success # actually I consider forbidding repositories not existent

    get '/source/home:Iggy/_meta'
    assert_not_equal original, @response.body

    assert_equal({ 'disable' => [{ 'arch' => 'i586', 'repository' => '10.2' },
                                 { 'arch' => 'x86_64', 'repository' => '10.2' }],
                   'enable' => { 'arch' => 'i586', 'repository' => '10.7' } },
                 Xmlhash.parse(@response.body)['build'])

    post '/source/home:Iggy?cmd=set_flag&flag=build&status=enable'
    assert_response :success

    get '/source/home:Iggy/_meta'
    assert_equal({ 'disable' => [{ 'arch' => 'i586', 'repository' => '10.2' },
                                 { 'arch' => 'x86_64', 'repository' => '10.2' }],
                   'enable' => [{ 'arch' => 'i586', 'repository' => '10.7' }, {}] },
                 Xmlhash.parse(@response.body)['build'])
  end

  def test_package_remove_flag
    login_Iggy

    get '/source/home:Iggy/TestPack/_meta'
    assert_response :success
    original = @response.body

    post '/source/home:unknown/Nothere?cmd=remove_flag&repository=10.2&arch=i586&flag=build'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)

    post '/source/home:Iggy/Nothere?cmd=remove_flag&repository=10.2&arch=i586'
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)

    post '/source/home:Iggy/Nothere?cmd=remove_flag&repository=10.2&arch=i586&flag=build'
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)

    post '/source/home:Iggy/TestPack?cmd=remove_flag&repository=10.2&arch=i586&flag=shine'
    assert_response :bad_request
    assert_match(/Error: unknown flag type 'shine' not found./, @response.body)

    get '/source/home:Iggy/TestPack/_meta'
    assert_response :success
    # so far noting should have changed
    assert_equal original, @response.body

    post '/source/kde4/kdelibs?cmd=remove_flag&repository=10.2&arch=x86_64&flag=debuginfo'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'cmd_execution_no_permission' }

    post '/source/home:Iggy/TestPack?cmd=remove_flag&repository=10.2&arch=x86_64&flag=debuginfo'
    assert_response :success

    get '/source/home:Iggy/TestPack/_meta'
    assert_not_equal original, @response.body

    # non existent repos should not change anything
    original = @response.body

    post '/source/home:Iggy/TestPack?cmd=remove_flag&repository=10.7&arch=x86_64&flag=debuginfo'
    assert_response :success # actually I consider forbidding repositories not existent

    get '/source/home:Iggy/TestPack/_meta'
    assert_equal original, @response.body
  end

  def test_project_remove_flag
    login_Iggy

    get '/source/home:Iggy/_meta'
    assert_response :success
    original = @response.body

    post '/source/home:unknown/Nothere?cmd=remove_flag&repository=10.2&arch=i586&flag=build'
    assert_response :not_found
    assert_match(/unknown_project/, @response.body)

    post '/source/home:Iggy/Nothere?cmd=remove_flag&repository=10.2&arch=i586&flag=build'
    assert_response :not_found
    assert_match(/unknown_package/, @response.body)

    post '/source/home:Iggy?cmd=remove_flag&repository=10.2&arch=i586&flag=shine'
    assert_response :bad_request
    assert_match(/Error: unknown flag type 'shine' not found./, @response.body)

    get '/source/home:Iggy/_meta'
    assert_response :success
    # so far noting should have changed
    assert_equal original, @response.body

    post '/source/kde4/kdelibs?cmd=remove_flag&repository=10.2&arch=x86_64&flag=debuginfo'
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'cmd_execution_no_permission' }

    post '/source/home:Iggy?cmd=remove_flag&repository=10.2&arch=x86_64&flag=debuginfo'
    assert_response :success

    get '/source/home:Iggy/_meta'
    assert_not_equal original, @response.body

    # non existent repos should not change anything
    original = @response.body

    post '/source/home:Iggy?cmd=remove_flag&repository=10.7&arch=x86_64&flag=debuginfo'
    assert_response :success # actually I consider forbidding repositories not existent

    get '/source/home:Iggy/_meta'
    assert_equal original, @response.body
  end

  def test_wild_chars
    login_Iggy
    get '/source/home:Iggy/TestPack'
    assert_response :success

    Backend::Connection.put('/source/home:Iggy/TestPack/bnc%23620675.diff?user=king', 'argl')
    assert_response :success

    get '/source/home:Iggy/TestPack'
    assert_response :success

    assert_xml_tag tag: 'directory', child: { tag: 'entry' }
    assert_xml_tag tag: 'directory',
                   children: { count: 1, only: { tag: 'entry', attributes: { name: 'bnc#620675.diff' } } }

    get '/source/home:Iggy/TestPack/bnc%23620675.diff'
    assert_response :success

    # cleanup
    delete '/source/home:Iggy/TestPack/bnc%23620675.diff'
    assert_response :success
  end

  def draft_xml_for_duplicate_test(package_or_project)
    # first we add a bugowner
    xml = if package_or_project == 'package'
            "<package project='home:Iggy' name='TestPack'>"
          else
            "<project name='home:Iggy'>"
          end
    xml += '<title>Strange XML</title><description></description>'
    # make sure never to erase ourselves
    xml += "<person userid='Iggy' role='maintainer'/>"
    xml += yield
    xml + "</#{package_or_project}>"
  end

  def duplicated_user_test(package_or_project, user_or_group, url)
    login_Iggy

    xml = draft_xml_for_duplicate_test(package_or_project) do
      if user_or_group == 'user'
        "<person userid='tom' role='bugowner'/>"
      else
        "<group groupid='test_group' role='bugowner'/>"
      end
    end

    put url, params: xml
    assert_response :success

    # then we add two times the maintainer
    xml = draft_xml_for_duplicate_test(package_or_project) do
      if user_or_group == 'user'
        "<person userid='tom' role='bugowner'/>
         <person userid='tom' role='maintainer'/>
         <person userid='tom' role='maintainer'/>"
      else
        "<group groupid='test_group' role='bugowner'/>
         <group groupid='test_group' role='maintainer'/>
         <group groupid='test_group' role='maintainer'/>"
      end
    end

    put url, params: xml
    assert_response :success

    get url
    Xmlhash.parse(@response.body)
  end

  def test_have_the_same_user_role_twice_in_package_meta
    login_tom
    get '/source/home:Iggy/_meta'
    assert_response :success
    orig_prj_meta = @response.body
    get '/source/home:Iggy/TestPack/_meta'
    assert_response :success
    orig_pkg_meta = @response.body

    ret = duplicated_user_test('package', 'user', '/source/home:Iggy/TestPack/_meta')
    assert_equal({ 'name' => 'TestPack',
                   'project' => 'home:Iggy',
                   'title' => 'Strange XML',
                   'description' => {},
                   'person' => [
                     { 'userid' => 'tom', 'role' => 'bugowner' },
                     { 'userid' => 'Iggy', 'role' => 'maintainer' },
                     { 'userid' => 'tom', 'role' => 'maintainer' }
                   ] }, ret)

    ret = duplicated_user_test('package', 'group', '/source/home:Iggy/TestPack/_meta')
    assert_equal({ 'name' => 'TestPack',
                   'project' => 'home:Iggy',
                   'title' => 'Strange XML',
                   'description' => {},
                   'person' => { 'userid' => 'Iggy', 'role' => 'maintainer' },
                   'group' => [
                     { 'groupid' => 'test_group', 'role' => 'bugowner' },
                     { 'groupid' => 'test_group', 'role' => 'maintainer' }
                   ] }, ret)

    ret = duplicated_user_test('project', 'user', '/source/home:Iggy/_meta')
    assert_equal({ 'name' => 'home:Iggy',
                   'title' => 'Strange XML',
                   'description' => {},
                   'person' => [
                     { 'userid' => 'tom', 'role' => 'bugowner' },
                     { 'userid' => 'Iggy', 'role' => 'maintainer' },
                     { 'userid' => 'tom', 'role' => 'maintainer' }
                   ] }, ret)

    ret = duplicated_user_test('project', 'group', '/source/home:Iggy/_meta')
    assert_equal({ 'name' => 'home:Iggy',
                   'title' => 'Strange XML',
                   'description' => {},
                   'person' => { 'userid' => 'Iggy', 'role' => 'maintainer' },
                   'group' => [
                     { 'groupid' => 'test_group', 'role' => 'bugowner' },
                     { 'groupid' => 'test_group', 'role' => 'maintainer' }
                   ] }, ret)

    # restore (esp in backend)
    login_king
    put '/source/home:Iggy/_meta', params: orig_prj_meta
    assert_response :success
    put '/source/home:Iggy/TestPack/_meta', params: orig_pkg_meta
    assert_response :success
  end

  def test_store_invalid_package
    login_tom
    name = Faker::Lorem.characters(number: 255)
    url = url_for(controller: :source_package_meta, action: :update, project: 'home:tom', package: name)
    put url, params: "<package name='#{name}' project='home:tom'> <title/> <description/></package>"
    assert_response :bad_request
    assert_select 'status[code] > summary', /invalid package name/
    get url
    assert_response :bad_request
    assert_select 'status[code] > summary', /invalid package name/
  end

  def test_store_invalid_project
    login_tom
    name = "home:tom:#{Faker::Lorem.characters(number: 255)}"
    url = url_for(controller: :source_project_meta, action: :update, project: name)
    put url, params: "<project name='#{name}'> <title/> <description/></project>"
    assert_response :bad_request
    assert_select 'status[code] > summary', /invalid project name/
    get url
    assert_response :bad_request
    assert_select 'status[code] > summary', /invalid project name/
  end

  # _attribute is a "file", but can only be written by API->backend not directly
  def test_puting__attribute_to_backend
    login_tom
    put '/source/home:tom/_project/_attribute?meta=1', params: ''
    assert_response :bad_request
    assert_select 'status[code] > summary', 'Attributes need to be changed through /source/home:tom/_attribute'
  end

  def test_obscpio_deltastore
    login_tom
    put('/source/home:tom:deltastore/_meta', params: '<project name="home:tom:deltastore"><title/><description/></project>')
    assert_response :success
    put('/source/home:tom:deltastore/deltapack/_meta', params: '<package name="deltapack" project="home:tom:deltastore"><title/><description/></package>')
    assert_response :success

    put '/source/home:tom:deltastore/deltapack/archive.obscpio', params: load_backend_file('source/deltapack/archive.obscpio')
    assert_response :success

    get '/source/home:tom:deltastore/deltapack'
    assert_response :success
    before_deltastore = @response.body

    deltastore = "#{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/sources/deltapack/deltastore"

    assert_not File.exist?(deltastore)
    run_deltastore
    assert File.exist?(deltastore)

    get '/source/home:tom:deltastore/deltapack'
    assert_response :success
    assert_equal before_deltastore, @response.body

    assert 0, run_admin("--show-delta-file #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/sources/deltapack/c1b8dd35488695c3c248f0acd447b4d5-archive.obscpio")

    delete '/source/home:tom:deltastore'
    assert_response :success
  end

  def test_issue_441
    login_tom
    get '/source/Foo'
    assert_response :not_found
    assert_equal({ 'code' => 'unknown_project', 'summary' => 'Project not found: Foo' }, Xmlhash.parse(@response.body))

    # and while we're at it, try it for packages too
    get '/source/Foo/bar'
    assert_response :not_found
    assert_equal({ 'code' => 'unknown_project', 'summary' => 'Project not found: Foo' }, Xmlhash.parse(@response.body))

    get '/source/home:tom/bar'
    assert_response :not_found
    assert_equal({ 'code' => 'unknown_package', 'summary' => 'Package not found: home:tom/bar' }, Xmlhash.parse(@response.body))
  end

  def test_repository_with_local_references
    # used to be obs#328
    login_tom
    # create a new project with images repo referencing the other
    put('/source/home:tom:threeatatime/_meta', params: '<project name="home:tom:threeatatime"> <title/> <description/>
           <repository name="images">
             <path project="home:tom:threeatatime" repository="standard"/>
           </repository>
           <repository name="standard">
             <path project="home:tom:threeatatime" repository="standard2"/>
           </repository>
           <repository name="standard2">
           </repository>
         </project>')
    assert_response :success
    get '/source/home:tom:threeatatime/_meta'
    assert_response :success
    assert_xml_tag tag: 'path', attributes: { project: 'home:tom:threeatatime', repository: 'standard' },
                   parent: { tag: 'repository', attributes: { name: 'images' } }
    assert_xml_tag tag: 'path', attributes: { project: 'home:tom:threeatatime', repository: 'standard2' },
                   parent: { tag: 'repository', attributes: { name: 'standard' } }
    assert_xml_tag tag: 'repository', attributes: { name: 'standard2' }

    raw_put('/source/home:tom:threeatatime/dummy/_meta', '<package name="dummy" project="home:tom:threeatatime"><title/><description/></package>')
    assert_response :success
    post '/source/home:tom:threeatatime/dummy?cmd=branch'
    assert_response :success

    get '/source/home:tom:branches:home:tom:threeatatime/_meta'
    assert_response :success
    assert_xml_tag tag: 'path', attributes: { project: 'home:tom:branches:home:tom:threeatatime', repository: 'standard' },
                   parent: { tag: 'repository', attributes: { name: 'images' } }
    assert_xml_tag tag: 'path', attributes: { project: 'home:tom:branches:home:tom:threeatatime', repository: 'standard2' },
                   parent: { tag: 'repository', attributes: { name: 'standard' } }
    assert_xml_tag tag: 'path', attributes: { project: 'home:tom:threeatatime', repository: 'standard2' },
                   parent: { tag: 'repository', attributes: { name: 'standard2' } }
    assert_xml_tag tag: 'repository', attributes: { name: 'standard2' }

    delete '/source/home:tom:branches:home:tom:threeatatime?force=1'
    assert_response :success
    delete '/source/home:tom:threeatatime?force=1'
    assert_response :success

    get '/source/home:tom:threeatatime'
    assert_response :not_found
  end

  def test_config_file
    login_Iggy

    get '/source/home:Iggy/_config'
    assert_response :success
    assert_equal @response.body.strip, File.read('test/fixtures/files/home_iggy_project_config.txt').strip
  end

  def test_updating_config_file
    project_config = File.read('test/fixtures/files/home_iggy_project_config.txt')
    new_project_config = File.read('test/fixtures/files/new_home_iggy_project_config.txt')

    login_Iggy

    put '/source/home:Iggy/_config?' + {
      project: 'home:Iggy',
      comment: 'Updated by test'
    }.to_query, params: new_project_config
    assert_response :success

    get '/source/home:Iggy/_config'
    assert_response :success
    assert_equal @response.body, new_project_config

    # Leave the backend file as it was
    put '/source/home:Iggy/_config?' + {
      project: 'home:Iggy',
      comment: 'Updated by test'
    }.to_query, params: project_config
    assert_response :success
  end
end
# rubocop:enable Metrics/ClassLength
