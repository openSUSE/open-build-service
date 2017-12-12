# encoding: UTF-8

require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class CrossBuildTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    reset_auth
  end

  def test_setup_project
    skip("hostsystem cleanup is currently broken, but neither supported")
    # best fix would be to drop the support again most likely
    login_tom
    put "/source/home:tom:CrossBuild/_meta", params: "<project name='home:tom:CrossBuild'> <title/> <description/>
            <repository name='standard'>
              <path repository='BaseDistro_repo' project='BaseDistro' />
              <hostsystem repository='BaseDistro2_repo' project='BaseDistro2.0' />
            </repository>
          </project>"
    assert_response :success
    get "/source/home:tom:CrossBuild/_meta"
    assert_response :success
    assert_xml_tag tag: "path", attributes: { project: 'BaseDistro', repository: 'BaseDistro_repo' }
    assert_xml_tag tag: "hostsystem", attributes: { project: 'BaseDistro2.0', repository: 'BaseDistro2_repo' }

    put "/source/home:tom:CrossBuild/_meta", params: "<project name='home:tom:CrossBuild'> <title/> <description/>
            <repository name='standard'>
              <path repository='BaseDistro_repo' project='BaseDistro' />
              <hostsystem repository='nada' project='HiddenProject' />
            </repository>
          </project>"
    assert_response 404
    assert_xml_tag tag: "status", attributes: { code: "unknown_project" }

    delete "/source/home:tom:CrossBuild"
    assert_response :success
    get "/source/BaseDistro2.0:LinkedUpdateProject/_meta"
    assert_response :success
    assert_no_xml_tag tag: "path", attributes: { project: "deleted" }
  end
end
