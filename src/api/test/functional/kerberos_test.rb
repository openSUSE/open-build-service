# encoding: UTF-8
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class KerberosTest < ActionDispatch::IntegrationTest
  fixtures :all

  setup do
    CONFIG['kerberos_keytab'] = "/etc/krb5.keytab"
    CONFIG['kerberos_service_principal'] = "HTTP/www.example.com@EXAMPLE.COM"
    CONFIG['kerberos_realm'] = "EXAMPLE.COM"
  end

  teardown do
    CONFIG.delete('kerberos_keytab')
    CONFIG.delete('kerberos_service_principal')
    CONFIG.delete('kerberos_realm')
  end

  def test_basic_login
    reset_auth

    get "/person/"
    assert_response 401

    login_trent

    unless File.exist? '/var/adm/fillup-templates'
      # FIXME: we have no kerberos setup in packages yet, but on travis.
      #        we need to solve this before making kerberos support official
      get "/person/"
      assert_response :success
    end

    reset_auth

    get "/person/"
    assert_response 401
  end

  def test_wrong_kerberos_password
    reset_auth

    prepare_request_with_krb_user 'trent', 'xxx'
    get "/person/"
    assert_response 401
  end

  def test_wrong_user_with_kerberos
    reset_auth

    prepare_request_with_krb_user 'king', 'tnert'
    get "/person/"
    assert_response 401
  end
end
