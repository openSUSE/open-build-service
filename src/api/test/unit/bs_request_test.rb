require_relative '../test_helper'

class BsRequestTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    User.session = users(:Iggy)
  end

  test 'if create works' do
    Backend::Test.start
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

    User.session = users(:unconfirmed_user)
    req = BsRequest.new_from_xml(xml)
    assert req.number.nil?
    exception = assert_raise(ActiveRecord::RecordInvalid) do
      req.save!
    end
    assert_match(/Validation failed: Creator Login unconfirmed_user is not an active user/, exception.message)
  end

  def test_target_maintainer
    req = bs_requests(:missing_source_project)

    assert req.target_maintainer?(users(:adrian))
    assert_not req.target_maintainer?(users(:user1))
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

    assert_equal req.state, :review
    assert_equal req.creator, 'Iggy'
    assert_equal req.target_maintainer?(nil), false

    wia = req.webui_actions(diffs: false)[0]
    assert_equal wia[:type], :add_role
    assert_equal wia[:tprj], 'kde4'
    assert_equal wia[:role], 'reviewer'
    assert_equal wia[:user], 'Iggy'

    assert_equal req.state, :review
    assert_equal req.creator, 'Iggy'
    assert_equal req.target_maintainer?(users(:fred)), true

    req.destroy
  end

  def test_parse_bigger
    xml = <<~XML
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
    new_time = Time.zone.local(2012, 11, 7, 0, 0, 0)
    travel_to(new_time) do
      req.save!
    end
    # number got increased by one
    assert_equal 1027, req.number

    newxml = req.render_xml
    expected = <<~XML
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
        <state name="review" who="Iggy" when="2012-11-07T21:13:12" created="2012-11-07T00:00:00">
          <comment>No comment</comment>
        </state>
        <review state="new" when="2017-09-01T09:11:11" by_user="adrian"/>
        <review state="new" when="2017-09-01T09:11:11" by_group="test_group"/>
        <review state="new" when="2012-11-07T21:13:12" who="tom" by_user="tom">
          <comment>review1</comment>
        </review>
        <review state="new" when="2012-11-07T21:13:13" who="tom" by_user="tom">
          <comment>please accept</comment>
        </review>
        <description>Left blank</description>
      </request>
    XML
    assert_equal expected, newxml

    # iggy is *not* target maintainer
    assert_equal req.target_maintainer?(users(:Iggy)), false
    wia = req.webui_actions(diffs: false)
    assert_equal wia[0], type: :submit,
                         id: wia[0][:id],
                         number: 1027,
                         sprj: 'home:Iggy',
                         spkg: 'TestPack',
                         srev: '1',
                         tprj: 'kde4',
                         tpkg: 'mypackage',
                         name: 'Submit TestPack',
                         diff_not_cached: false
  end

  def test_if_delegate_works
    # ensure that update project lacks the package to cover update_instance delegation as well
    assert Package.find_by_project_and_name('BaseDistro:Update', 'pack1').nil?

    xml = '<request>
              <action type="submit">
                <source project="BaseDistro3" package="pack2"/>
                <target project="BaseDistro:SP1" package="pack1"/>
              </action>
              <state name="new" />
          </request>'
    req = BsRequest.new_from_xml(xml)
    assert req.number.nil?
    assert_equal 1, req.bs_request_actions.length
    req.save!
    # normal behaviour, target project is used
    assert_equal 'BaseDistro:SP1', req.bs_request_actions.first.target_project

    # enable delegation
    attrib_type = AttribType.find_by_namespace_and_name('OBS', 'DelegateRequestTarget')
    attrib = Attrib.new(attrib_type: attrib_type)
    attrib.project = Project.find_by_name('BaseDistro:SP1')
    attrib.save

    # check delegation to BaseDistro:Update via BaseDistro where the package lives
    req = BsRequest.new_from_xml(xml)
    exception = assert_raise(BsRequestAction::Errors::SubmitRequestRejected) do
      req.save!
    end
    assert_match(/The target project BaseDistro:Update is a maintenance release project/, exception.message)
  end

  def check_user_targets(user, *trues)
    Backend::Test.start
    BsRequest.find_each do |r|
      # puts r.render_xml
      expect = trues.include?(r.number)
      assert_equal expect, r.target_maintainer?(User.find_by_login(user)),
                   "Request #{r.number} should have #{expect} in target_maintainer for #{user}"
    end
  end

  def test_review_changestate
    xml = <<~XML
      <request id="1027" creator="Iggy">
        <action type="submit">
          <source project="home:Iggy" package="TestPack" rev="1"/>
          <target project="kde4" package="mypackage"/>
        </action>
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
    new_time = Time.zone.local(2012, 11, 7, 0, 0, 0)
    travel_to(new_time) do
      req.save!
    end

    # decline review
    req.change_review_state(:declined, { by_group: 'test_group' })
    assert_equal :declined, req.state

    # reopen the request leads to request into review state again
    req.change_review_state(:new, { by_group: 'test_group' })
    assert_equal :review, req.state
  end

  test 'request ownership' do
    check_user_targets(:Iggy, 10)
    check_user_targets(:adrian, 1, 1000)
  end
end
