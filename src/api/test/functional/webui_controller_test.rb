require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class WebuiControllerTest < ActionDispatch::IntegrationTest

  fixtures :all

  def setup
    super
    wait_for_scheduler_start
  end

  test 'package rdiff' do
    login_Iggy

    get '/webui/projects/BaseDistro2.0/packages/pack2.linked/rdiff?linkrev=&opackage=pack2&oproject=BaseDistro2.0&orev=&rev='
    assert_response 400
    assert_xml_tag tag: 'summary', content: 'Error getting diff: revision is empty'
  end
end
