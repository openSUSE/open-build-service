# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class BsRequestTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    User.current = users(:Iggy)
  end

  test 'if create works' do
    xml = '<request>
              <action type="submit">
                <source project="BaseDistro" package="pack2" rev="1"/>
                <target project="home:tom" package="pack1"/>
              </action>
              <state name="new" />
          </request>'
    req = BsRequest.new_from_xml(xml)
    assert req.number.nil?
    assert_equal 1, req.bs_request_actions.length
    req.save!

    User.current = users(:_nobody_)
    req = BsRequest.new_from_xml(xml)
    assert req.number.nil?
    exception = assert_raise ActiveRecord::RecordInvalid do
      req.save!
    end
    assert_match(/Validation failed: Creator Login _nobody_ is not an active user/, exception.message)
  end

  def test_target_maintainer
    req = bs_requests(:missing_source_project)

    assert req.is_target_maintainer?(users(:adrian))
    assert !req.is_target_maintainer?(users(:user1))
  end

  def test_incremental_request_numbers
    req = BsRequest.new_from_xml(load_backend_file('request/add_role'))
    req.save!
    req2 = BsRequest.new_from_xml(load_backend_file('request/add_role'))
    req2.save!
    req3 = BsRequest.new_from_xml(load_backend_file('request/add_role'))
    req3.save!

    assert_equal req.number + 1, req2.number
    assert_equal req.number + 2, req3.number
  end

  def test_add_role
    req = BsRequest.new_from_xml(load_backend_file('request/add_role'))
    req.save!

    wi = req.webui_infos(diffs: false)
    assert_equal wi['number'], req.number
    assert_equal wi['description'], ''
    assert_equal wi['state'], :review
    assert_equal wi['creator'].login, 'Iggy'
    assert_equal wi['is_target_maintainer'], false
    assert_equal wi['my_open_reviews'], []

    wia = wi['actions'][0]
    assert_equal wia[:type], :add_role
    assert_equal wia[:tprj], 'kde4'
    assert_equal wia[:role], 'reviewer'
    assert_equal wia[:user], 'Iggy'

    User.current = users(:fred)

    wi = req.webui_infos(diffs: false)
    assert_equal wi['id'], req.id
    assert_equal wi['number'], req.number
    assert_equal wi['description'], ''
    assert_equal wi['state'], :review
    assert_equal wi['creator'].login, 'Iggy'
    assert_equal wi['is_target_maintainer'], true
    assert_equal wi['my_open_reviews'], []

    req.destroy
  end

  test 'change_review' do
    req = BsRequest.new_from_xml(load_backend_file('request/add_role'))
    req.save!
    req.addreview(by_user: 'tom', comment: 'does it look ok?')
    assert_raises BsRequest::InvalidReview do
      req.change_review_state('accepted')
    end
    assert_raise Review::NotFoundError do
      req.change_review_state('accepted', by_user: 'Iggy') # cheater!
    end
    req.change_review_state('accepted', by_user: 'tom') # he's allowed to - for some reason
  end

  def test_parse_bigger
    xml = <<-XML.strip_heredoc
      <request id="1027" creator="Iggy">
        <action type="submit">
          <source project="home:Iggy" package="TestPack" rev="1"/>
          <target project="kde4" package="mypackage"/>
          <options>
            <sourceupdate>cleanup</sourceupdate>
          </options>
          <acceptinfo rev="1" srcmd5="806a6e27ed7915d1bb8d8a989404fd5a" osrcmd5="d41d8cd98f00b204e9800998ecf8427e"/>
        </action>
        <priority>critical</priority>
        <state name="review" who="Iggy" when="2012-11-07T21:13:12">
          <comment>No comment</comment>
        </state>
        <review state="new" when="2017-09-01T09:11:11" by_user="adrian"/>
        <review state="new" when="2017-09-01T09:11:11" by_group="test_group"/>
        <review state="accepted" when="2012-11-07T21:13:12" who="tom" by_user="tom">
          <comment>review1</comment>
        </review>
        <review state="new" when="2012-11-07T21:13:13" who="tom" by_user="tom">
          <comment>please accept</comment>
        </review>
        <description>Left blank</description>
      </request>
    XML
    req = BsRequest.new_from_xml(xml)
    req.save!
    # number got increased by one
    assert_equal 1027, req.number

    newxml = req.render_xml
    assert_equal xml, newxml

    wi = req.webui_infos(diffs: false)
    # iggy is *not* target maintainer
    assert_equal false, wi['is_target_maintainer']
    assert_equal wi['actions'][0], type: :submit,
                                   sprj: 'home:Iggy',
                                   spkg: 'TestPack',
                                   srev: '1',
                                   tprj: 'kde4',
                                   tpkg: 'mypackage',
                                   name: 'Submit TestPack'
  end

  def check_user_targets(user, *trues)
    Backend::Test.start
    User.current = User.find_by_login(user)
    BsRequest.all.each do |r|
      # puts r.render_xml
      expect = trues.include?(r.number)
      assert_equal expect, r.webui_infos(diffs: false)['is_target_maintainer'],
                   "Request #{r.number} should have #{expect} in target_maintainer for #{user}"
    end
  end

  test 'request ownership' do
    check_user_targets(:Iggy, 10)
    check_user_targets(:adrian, 1, 1000)
  end
end
