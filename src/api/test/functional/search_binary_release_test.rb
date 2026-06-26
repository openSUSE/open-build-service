require_relative '../test_helper'
require 'xmlhash'

class SearchBinaryReleaseTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    reset_auth
  end

  def test_search_binary_release_in_fixtures
    disturl = 'obs://build.opensuse.org/My:Maintenance:2793/openSUSE_13.1_Update/904dbf574823ac4ca7501a1f4dca0e68-package.openSUSE_13.1_Update'

    reset_auth
    get '/search/released/binary', params: { match: "@name = 'package'" }
    assert_response :unauthorized

    login_Iggy
    get '/search/released/binary/id', params: { match: "@name = 'package'" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }

    get '/search/released/binary/id', params: { match: "build/@binaryid = '5bb6f78d6a24f084e58e476955f615ec'" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }

    # full content
    get '/search/released/binary', params: { match: "@name = 'package'" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }
    assert_xml_tag tag: 'disturl', content: disturl
    assert_xml_tag tag: 'maintainer', content: 'Iggy'
    assert_xml_tag tag: 'supportstatus', content: 'l3'
    assert_xml_tag tag: 'publish', attributes: { time: '2013-09-30 15:50:30 UTC', package: 'pack2' }
    assert_xml_tag tag: 'build', attributes: { time: '2013-09-29 15:50:31 UTC' }

    # by updateinfo identifier
    get '/search/released/binary/id', params: { match: "updateinfo/@id = 'OBS-2014-42'" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }

    # by disturl
    get '/search/released/binary/id', params: { match: "disturl = '#{disturl}'" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }

    # by cpeid ... we have no data, but must not crash at least
    get '/search/released/binary', params: { match: 'cpeid' }
    assert_response :success

    # search via publish container
    get '/search/released/binary/id', params: { match: "publish/@package = 'pack2'" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }
    get '/search/released/binary/id', params: { match: "publish/@time = '2013-09-30 15:50:30 UTC'" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }

    # exact search
    get '/search/released/binary', params: { match: "@name = 'package' and @version = '1.0' and @release = '1' and @arch = 'i586' and supportstatus = 'l3' and operation = 'added'" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }

    # not matching
    get '/search/released/binary', params: { match: "@name = 'package' and @version = '1.1'" }
    assert_response :success
    assert_no_xml_tag tag: 'binary'

    # by repo
    get '/search/released/binary', params: { match: "repository[@project = 'BaseDistro3' and @name = 'BaseDistro3_repo']" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }
    assert_xml_tag tag: 'obsolete'

    # without obsolete rpms
    get '/search/released/binary', params: { match: "repository[@project = 'BaseDistro3' and @name = 'BaseDistro3_repo']" }
    assert_response :success
    assert_xml_tag tag: 'obsolete'
    get '/search/released/binary', params: { match: "repository[@project = 'BaseDistro3' and @name = 'BaseDistro3_repo'] and obsolete[not(@time)]" }
    assert_response :success
    assert_no_xml_tag tag: 'obsolete'
    get '/search/released/binary', params: { match: "repository[@project = 'BaseDistro3' and @name = 'BaseDistro3_repo'] and not(obsolete/@time)" }
    assert_response :success
    assert_no_xml_tag tag: ''
    get '/search/released/binary', params: { match: "repository[@project = 'BaseDistro3' and @name = 'BaseDistro3_repo'] and not(obsolete/@time=123)" }
    assert_response :success
    assert_xml_tag tag: 'obsolete'

    # without modified rpms
    get '/search/released/binary', params: { match: "repository[@project = 'BaseDistro3' and @name = 'BaseDistro3_repo'] and modify[not(@time)]" }
    assert_response :success
    assert_no_xml_tag tag: 'modify'

    # by product
    get '/search/released/binary', params: { match: "product[@project = 'BaseDistro' and @name = 'fixed' and (@arch = 'i586' or not(@arch))]" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586', medium: 'DVD' }
    assert_xml_tag tag: 'updatefor', attributes: { project: 'BaseDistro', product: 'fixed' }
    assert_xml_tag tag: 'product', attributes: { name: 'fixed', version: '1.2' }
    get '/search/released/binary', params: { match: "product[@project = 'BaseDistro' and @name = 'fixed' and @medium = 'DVD']" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586', medium: 'DVD' }
    # by version
    get '/search/released/binary', params: { match: "product[@project = 'BaseDistro' and @name = 'fixed' and @version = '1.2']" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586', medium: 'DVD' }
    # not matching version
    get '/search/released/binary', params: { match: "product[@project = 'BaseDistro' and @name = 'fixed' and @version = '2.99']" }
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '0' }
    assert_no_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586', medium: 'DVD' }
    # baseversion
    get '/search/released/binary', params: { match: "product[@project = 'BaseDistro' and @name = 'fixed' and @baseversion = '1.2' and @patchlevel='0']" }
    assert_response :success
    # not matching baseversion
    get '/search/released/binary', params: { match: "product[@project = 'BaseDistro' and @name = 'fixed' and @baseversion = '1.2' and @patchlevel='43']" }
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '0' }

    # by update for product
    get '/search/released/binary', params: { match: "updatefor[@project = 'BaseDistro' and @product = 'fixed' and @arch = 'i586']" }
    assert_response :success
    assert_no_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3' }
    get '/search/released/binary', params: { match: "updatefor[@project = 'BaseDistro' and @product = 'fixed' and @arch = 'x86_64']" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }
    assert_xml_tag tag: 'updatefor', attributes: { project: 'BaseDistro', product: 'fixed' }

    # by version
    get '/search/released/binary', params: { match: "updatefor[@project = 'BaseDistro' and @product = 'fixed' and @baseversion = '1.2' and @patchlevel='0']" }
    assert_response :success
    get '/search/released/binary', params: { match: "updatefor[@project = 'BaseDistro' and @product = 'fixed' and @version = '1.2']" }
    assert_response :success
    # not matching
    get '/search/released/binary', params: { match: "updatefor[@project = 'BaseDistro' and @product = 'fixed' and @version = '1.3']" }
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '0' }

    # basic no-crash tests
    get '/search/released/binary', params: { match: "updatefor/@version = '1.3'" }
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '0' }
    get '/search/released/binary', params: { match: "updatefor/@baseversion = '1.3'" }
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '0' }
    get '/search/released/binary', params: { match: "updatefor/@patchlevel = '1.3'" }
    assert_response :success
    assert_xml_tag tag: 'collection', attributes: { matches: '0' }

    # by update for product OR product itself
    get '/search/released/binary', params: { match: "product[@project = 'BaseDistro' and @name = 'fixed'] or updatefor[@project = 'BaseDistro' and @product = 'fixed']" }
    assert_response :success
    assert_xml_tag tag: 'binary', attributes: { project: 'BaseDistro3', repository: 'BaseDistro3_repo', name: 'package', version: '1.0', release: '1', arch: 'i586' }
    assert_xml_tag tag: 'updatefor', attributes: { project: 'BaseDistro', product: 'fixed' }
    assert_xml_tag tag: 'product', attributes: { name: 'fixed', version: '1.2' }
  end
end
