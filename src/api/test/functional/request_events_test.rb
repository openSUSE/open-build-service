# encoding: UTF-8

require_relative '../test_helper'

class RequestEventsTest < ActionDispatch::IntegrationTest
  fixtures :all

  teardown do
    Timecop.return
  end

  setup do
    ActionMailer::Base.deliveries.clear
    reset_auth
  end

  def verify_email(fixture_name, myid, email)
    should = load_fixture("event_mailer/#{fixture_name}").gsub('REQUESTID', myid).chomp
    assert_equal should, email.encoded.lines.map(&:chomp).select { |l| l !~ %r{^Date:} }.join("\n")
  end

  def test_request_event
    login_Iggy

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = 0
    SendEventEmailsJob.new.perform
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      post '/request?cmd=create',
           params: "<request><action type='add_role'><target project='home:tom'/><person name='Iggy' role='reviewer'/></action></request>"
      assert_response :success
      myid = Xmlhash.parse(@response.body)['id']
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} created by Iggy (add_role home:tom)", email.subject
    assert_equal %w(tschmidt@example.com), email.to # tom is maintainer
    verify_email('request_event', myid, email)
  end

  def test_very_large_request_event
    login_Iggy

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = 0
    SendEventEmailsJob.new.perform
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      body = "<request>\n"
      actions = 1000
      actions.times do
        body += "<action type='add_role'><target project='home:tom'/><person name='Iggy' role='reviewer'/></action>\n"
      end
      body += "</request>"
      post '/request?cmd=create', params: body
      assert_response :success
      req = Xmlhash.parse(@response.body)
      assert_equal actions, req['action'].count
      myid = req['id']
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last

    assert_match(/^Request #{myid} created by Iggy \(add_role home:tom, /, email.subject)
    assert_equal %w(tschmidt@example.com), email.to # tom is maintainer
  end

  def test_set_bugowner_event
    login_Iggy

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = 0
    SendEventEmailsJob.new.perform
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      post '/request?cmd=create', params: "<request><action type='set_bugowner'><target project='home:tom'/><person name='Iggy'/></action></request>"
      assert_response :success
      myid = Xmlhash.parse(@response.body)['id']
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} created by Iggy (set_bugowner home:tom)", email.subject
    assert_equal %w(tschmidt@example.com), email.to
    verify_email('set_bugowner_event', myid, email)

    ActionMailer::Base.deliveries.clear

    login_tom

    # now check if Iggy (the creator) gets an email about revokes
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      post "/request/#{myid}?cmd=changestate&newstate=declined", params: ''
      assert_response :success
      SendEventEmailsJob.new.perform
    end
    email = nil
    ActionMailer::Base.deliveries.each do |m|
      email = m if m.to.include? 'Iggy@pop.org'
    end

    assert_equal "Request #{myid} changed to declined (set_bugowner home:tom)", email.subject
    verify_email('tom_declined', myid, email)
  end

  def test_devel_package_event
    login_Iggy

    # for this test, ignore reviewers
    packages(:kde4_kdelibs).relationships.where(role: Role.hashed['reviewer']).delete_all
    projects(:kde4).relationships.where(role: Role.hashed['reviewer']).delete_all

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = ''
    SendEventEmailsJob.new.perform
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      post '/request?cmd=create',
           params: "<request><action type='add_role'><target project='kde4' package='kdelibs'/><person name='Iggy' role='reviewer'/></action>"\
                   "</request>"
      assert_response :success
      myid = Xmlhash.parse(@response.body)['id']
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    # what we want to test here is that tom - as devel package maintainer gets an email too
    verify_email('tom_gets_mail_too', myid, email)
  end

  def test_repository_delete_request
    login_Iggy

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = ''
    SendEventEmailsJob.new.perform
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      post '/request?cmd=create', params: "<request><action type='delete'><target project='home:coolo' repository='standard'/></action></request>"
      assert_response :success
      myid = Xmlhash.parse(@response.body)['id']
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    # what we want to test here is that tom - as devel package maintainer gets an email too
    verify_email('repo_delete_request', myid, email)
  end
end
