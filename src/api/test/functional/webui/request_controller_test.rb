require_relative '../../test_helper'

class Webui::RequestControllerTest < Webui::IntegrationTest

  uses_transaction :test_can_request_role_addition_for_packages
  uses_transaction :test_can_request_role_addition_for_projects
  uses_transaction :test_submit_package_and_revoke
  uses_transaction :test_comment_event

  fixtures :all

  teardown do
    Timecop.return
  end

  def setup
    super
    use_js
    ActionMailer::Base.deliveries.clear
  end

  def before_setup
    super
    # we need to do this as transaction rollback does not reset the ids
    # and we rely on fixed request ids in tests
    BsRequest.connection.execute('alter table bs_requests AUTO_INCREMENT = 1001')
  end

  def test_my_involved_requests
    login_Iggy to: user_requests_path(user: 'king')

    page.must_have_selector 'table#request_table tr'

    # walk over the table
    rs = find('tr#tr_request_1').find('.request_target')
    rs.find(:xpath, '//a[@title="kde4"]').must_have_text 'kde4'
    rs.find(:xpath, '//a[@title="kdelibs"]').must_have_text 'kdelibs'
  end

  test 'can request role addition for projects' do
    login_Iggy to: project_show_path(project: 'home:tom')
    click_link 'Request role addition'
    find(:id, 'role').select('Bugowner')
    fill_in 'description', with: 'I can fix bugs too.'
    click_button 'Ok'
    # request created
    page.must_have_text 'Iggy Pop (Iggy) wants the role bugowner for project home:tom'
    find('#description_text').must_have_text 'I can fix bugs too.'
    page.must_have_selector(:xpath, "//input[@name='revoked']")
    page.must_have_text('In state new')

    logout
    login_tom to: request_show_path(1001)
    page.must_have_text 'Iggy Pop (Iggy) wants the role bugowner for project home:tom'
    click_button 'Accept'
  end

  test 'can request role addition for packages' do
    login_Iggy to: package_show_path(project: 'home:Iggy', package: 'TestPack')
    # no need for "request role"
    page.wont_have_link 'Request role addition'
    # foreign package
    visit package_show_path(project: 'Apache', package: 'apache2')
    find(:css, 'a > img.icons-user_add').click
    find(:id, 'role').select('Maintainer')
    fill_in 'description', with: 'I can fix bugs too.'
    click_button 'Ok'
    # request created
    find('#action_display_0').must_have_text 'Iggy Pop (Iggy) wants the role maintainer for package Apache / apache2'
    find('#description_text').must_have_text 'I can fix bugs too.'
    page.must_have_selector(:xpath, "//input[@name='revoked']")
    page.must_have_text('In state new')

    logout
    login_tom to: request_show_path(1001)
    find('#action_display_0').must_have_text 'Iggy Pop (Iggy) wants the role maintainer for package Apache / apache2'
    # tom is not apache maintainer
    page.wont_have_button 'Accept'

    logout
    login_fred to: request_show_path(1001)
    find('#action_display_0').must_have_text 'Iggy Pop (Iggy) wants the role maintainer for package Apache / apache2'
    click_button 'Accept'

    # now check the role addition link is gone
    logout
    login_Iggy to: package_show_path(project: 'Apache', package: 'apache2')
    page.wont_have_link 'Request role addition'

  end

  test 'invalid id gives error' do
    login_Iggy
    visit request_show_path(2000)
    page.must_have_text("Can't find request 2000")
    page.must_have_text('Requests for Iggy')
  end

  test 'submit package and revoke' do
    login_Iggy to: package_show_path(project: 'home:Iggy', package: 'TestPack')
    click_link 'Submit package'
    fill_in 'targetproject', with: 'home:tom'
    fill_in 'description', with: 'Want it?'
    click_button 'Ok'

    page.must_have_text 'Created submit request 1001 to home:tom'
    click_link 'submit request 1001'

    # request view shows diff
    page.must_have_text '+Group: Group/Subgroup'

    # tab
    page.must_have_text 'My Decision'
    fill_in 'reason', with: 'Great work!'
    page.wont_have_selector 'input#accept_request_button'

    fill_in 'reason', with: 'Oops'
    click_button 'Revoke request'

    page.must_have_text 'Request revoked!'
    page.must_have_text 'Request 1001 (revoked)'
    page.must_have_text "There's nothing to be done right now"
  end

  test 'tom adds reviewer Iggy' do
    login_tom to: user_show_path(user: 'tom')

    within('tr#tr_request_4') do
      page.must_have_text '~:kde4 / BranchPack'
      first(:css, 'a.request_link').click
    end

    page.must_have_text 'Review for tom'

    click_link 'Add a review'
    page.must_have_text 'Add Reviewer'
    #test switching reviewer type
    find(:id, 'review_type').select('Group')
    page.must_have_text 'Group:'
    fill_in 'review_group', with: 'test_group_b'
    click_button 'Ok'
    page.must_have_text 'Open review for test_group'

    click_link 'Add a review'
    find(:id, 'review_type').select('Project')
    page.must_have_text 'Project:'
    fill_in 'review_project', with: 'home:Iggy'
    click_button 'Ok'
    page.must_have_text 'Open review for home:Iggy'

    click_link 'Add a review'
    find(:id, 'review_type').select('Package')
    page.must_have_text 'Project:'
    fill_in 'review_project', with: 'home:Iggy'
    page.must_have_text 'Package:'
    fill_in 'review_package', with: 'TestPack'
    click_button 'Ok'
    page.must_have_text 'Open review for home:Iggy / TestPack'

    click_link 'Add a review'
    find(:id, 'review_type').select('User')
    page.must_have_text 'User:'
    fill_in 'review_user', with: 'Iggy'
    click_button 'Ok'
    page.must_have_text 'Open review for Iggy'
    page.must_have_text 'Request 4 (review)'

    logout
    login_Iggy to: request_show_path(4)
    click_link('review_descision_link_0')
    fill_in 'review_comment_0', with: 'Ok for the project'
    click_button 'review_accept_button_0'
    page.must_have_text 'Ok for the project'
    click_link('review_descision_link_0')
    fill_in 'review_comment_0', with: 'Ok for the package'
    click_button 'review_accept_button_0'
    page.must_have_text 'Ok for the package'
    click_link 'review_descision_link_0'
    fill_in 'review_comment_0', with: 'And ok for me'
    click_button 'review_accept_button_0'
    page.must_have_text 'And ok for me'
    logout

    login_adrian to: request_show_path(4)
    click_link 'review_descision_link_0'
    fill_in 'review_comment_0', with: 'BranchPack sounds strange'
    click_button 'review_decline_button_0'
    page.must_have_text 'Request 4 (declined)'
  end

  test 'request 4 can expand' do
    # no login required
    visit request_show_path(4)
    within '#diff_headline_myfile_diff_action_0_submit_0_0' do
      page.wont_have_text '+DummyContent'
      click_link '[+]'
      page.wont_have_text '[+]'
      page.must_have_text '[-]'
    end

    # diff is expanded
    page.must_have_text '+DummyContent'
  end

  def visit_requests
    visit request_show_path(1)
    page.must_have_text 'Request 1'

    visit request_show_path(2)
    page.must_have_text 'Request 2'

    visit request_show_path(10)
    page.must_have_text 'Request 10'
  end

  test 'requests display as nobody' do
    visit_requests
  end

  test 'requests display as king' do
    login_king
    visit_requests
  end

  test 'succesful comment creation' do
    login_Iggy to: request_show_path(1)
    fill_in 'title', with: 'Comment Title'
    fill_in 'body', with: 'Comment Body'
    find_button('Add comment').click
    find('#flash-messages').must_have_text 'Comment added successfully '
  end

  test 'can not accept own requests' do
    login_tom to: package_show_path(project: 'Apache', package: 'apache2')
    click_link 'Submit package'
    fill_in 'targetproject', with: 'kde4'
    fill_in 'description', with: 'I want to see his reaction'
    uncheck('supersede')
    click_button 'Ok'
    click_link 'submit request 1001'
    # request history
    page.must_have_text %r{created request.*now}
    page.must_have_selector 'input#revoke_request_button'
    page.wont_have_selector 'input#accept_request_button'
  end

  test 'succesful reply comment creation' do
    login_Iggy to: request_show_path(4)
    find(:id, 'reply_link_id_301').click
    fill_in 'reply_body_301', with: 'Comment Body'
    find(:id, 'add_reply_301').click
    find('#flash-messages').must_have_text 'Comment added successfully '
  end

  def verify_email(fixture_name, myid, email)
    should = load_fixture("event_mailer/#{fixture_name}").gsub('REQUESTID', myid).chomp
    assert_equal should, email.encoded.lines.map(&:chomp).select { |l| l !~ %r{^Date:} }.join("\n")
  end

  test 'comment event' do
    login_tom to: request_show_path(4)

    # adrian is reviewer, Iggy creator, Admin (fixture) commenter
    # tom is commenter *and* author, so doesn't get mail
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      fill_in 'title', with: 'Comment Title'
      fill_in 'body', with: 'Comment Body'
      find_button('Add comment').click
      page.must_have_text 'Comment Title'
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal 'New comment in request 4 by tom: Comment Title', email.subject
    verify_email('comment_event', '4', email)

    # now check the commenters get no more mails too if unsubscribed
    EventSubscription.where(eventtype: 'Event::CommentForRequest', receiver_role: :commenter).delete_all

    ActionMailer::Base.deliveries.clear

    # adrian is reviewer, Iggy creator, Admin (fixture) commenter
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      fill_in 'title', with: 'Another Title'
      fill_in 'body', with: 'Another Body'
      find_button('Add comment').click
      page.must_have_text 'Another Title'
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal 'New comment in request 4 by tom: Another Title', email.subject
    verify_email('another_comment_event', '4', email)
  end
end

