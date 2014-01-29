# encoding: UTF-8
require_relative '../test_helper'

class RequestEventsTest < ActionDispatch::IntegrationTest

  fixtures :all

  teardown do
    Timecop.return
  end

  setup do
    ActionMailer::Base.deliveries.clear
  end

  def verify_email(fixture_name, myid, email)
    should = load_fixture("event_mailer/#{fixture_name}").gsub('REQUESTID', myid).chomp
    assert_equal should, email.encoded.lines.map(&:chomp).select { |l| l !~ %r{^Date:} }.join("\n")
  end

  test 'request event' do
    login_Iggy

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = 0
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post '/request?cmd=create', "<request><action type='add_role'><target project='home:tom'/><person name='Iggy' role='reviewer'/></action></request>"
      assert_response :success
      myid = Xmlhash.parse(@response.body)['id']
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} created by Iggy (add_role home:tom)", email.subject
    assert_equal %w(tschmidt@example.com), email.to # tom is maintainer
    verify_email('request_event', myid, email)
  end

  test 'set_bugowner event' do
    login_Iggy

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = 0
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post '/request?cmd=create', "<request><action type='set_bugowner'><target project='home:tom'/><person name='Iggy'/></action></request>"
      assert_response :success
      myid = Xmlhash.parse(@response.body)['id']
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} created by Iggy (set_bugowner home:tom)", email.subject
    assert_equal %w(tschmidt@example.com), email.to
    verify_email('set_bugowner_event', myid, email)

    ActionMailer::Base.deliveries.clear

    login_tom

    # now check if Iggy (the creator) gets an email about revokes
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post "/request/#{myid}?cmd=changestate&newstate=declined", ''
      assert_response :success
    end
    email = nil
    ActionMailer::Base.deliveries.each do |m|
      email = m if m.to.include? 'Iggy@pop.org'
    end

    assert_equal "Request #{myid} changed to declined (set_bugowner home:tom)", email.subject
    verify_email('tom_declined', myid, email)
  end

  test 'group emails' do
    User.current = users(:Iggy)

    # the default is reviewer groups get email, so check that adrian gets an email
    req = bs_requests(:submit_from_home_project)
    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = req.id
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      req.addreview(by_group: 'test_group', comment: 'does it look ok?')
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} requires review (submit Apache/BranchPack)", email.subject
    assert_equal %w(adrian@example.com), email.to
  end

  # now check that disabling it for adrian works too
  test 'group emails disabled' do
    login_Iggy

    # the default is reviewer groups get email, so check that adrian gets an email
    req = bs_requests(:submit_from_home_project)

    GroupsUser.where(user: users(:adrian), group: groups(:test_group)).first.update_attribute(:email, false)
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      req.addreview(by_group: 'test_group', comment: 'does it still look ok?')
    end
  end

  test 'devel package event' do
    login_Iggy

    # for this test, ignore reviewers
    packages(:kde4_kdelibs).relationships.where(role: Role.rolecache['reviewer']).delete_all
    projects(:kde4).relationships.where(role: Role.rolecache['reviewer']).delete_all

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = ''
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post '/request?cmd=create', "<request><action type='add_role'><target project='kde4' package='kdelibs'/><person name='Iggy' role='reviewer'/></action></request>"
      assert_response :success
      myid = Xmlhash.parse(@response.body)['id']
    end

    email = ActionMailer::Base.deliveries.last
    # what we want to test here is that tom - as devel package maintainer gets an email too
    verify_email('tom_gets_mail_too', myid, email)
  end

  test 'repository delete request' do
    login_Iggy

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = ''
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post '/request?cmd=create', "<request><action type='delete'><target project='home:coolo' repository='standard'/></action></request>"
      assert_response :success
      myid = Xmlhash.parse(@response.body)['id']
    end

    email = ActionMailer::Base.deliveries.last
    # what we want to test here is that tom - as devel package maintainer gets an email too
    verify_email('repo_delete_request', myid, email)
  end
end
