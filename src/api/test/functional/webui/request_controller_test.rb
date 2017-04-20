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

  def test_my_involved_requests # spec/controllers/webui/user_controller_spec.rb
    login_king to: user_show_path(user: 'king')

    page.must_have_selector 'table#requests_in_table tr'

    find(:xpath, '//a[@title="kde4"]').must_have_text 'kde4'
    find(:xpath, '//a[@title="kdelibs"]').must_have_text 'kdelibs'
  end

  def test_can_request_role_addition_for_projects # spec/features/webui/requests_spec.rb
    login_Iggy to: project_show_path(project: 'home:tom')
    click_link 'Request role addition'
    find(:id, 'role').select('Bugowner')
    fill_in 'description', with: 'I can fix bugs too.'
    click_button 'Ok'
    requestid = current_path.gsub(%r{\/request\/show\/(\d*)}, '\1').to_i
    page.must_have_text 'Iggy Pop (Iggy) wants the role bugowner for project home:tom'
    find('#description-text').must_have_text 'I can fix bugs too.'
    page.must_have_selector(:xpath, "//input[@name='revoked']")
    page.must_have_text('In state new')

    logout
    login_tom to: request_show_path(requestid)
    page.must_have_text 'Iggy Pop (Iggy) wants the role bugowner for project home:tom'
    click_button 'Accept'
  end

  def test_can_request_role_addition_for_packages # spec/features/webui/requests_spec.rb
    login_Iggy to: package_show_path(project: 'home:Iggy', package: 'TestPack')
    # no need for "request role"
    page.wont_have_link 'Request role addition'
    # foreign package
    visit package_show_path(project: 'Apache', package: 'apache2')
    find(:css, 'a > img.icons-user_add').click
    find(:id, 'role').select('Maintainer')
    fill_in 'description', with: 'I can fix bugs too.'
    click_button 'Ok'
    requestid = current_path.gsub(%r{\/request\/show\/(\d*)}, '\1').to_i
    find('#action_display_0').must_have_text 'Iggy Pop (Iggy) wants the role maintainer for package Apache / apache2'
    find('#description-text').must_have_text 'I can fix bugs too.'
    page.must_have_selector(:xpath, "//input[@name='revoked']")
    page.must_have_text('In state new')

    logout
    login_tom to: request_show_path(requestid)
    find('#action_display_0').must_have_text 'Iggy Pop (Iggy) wants the role maintainer for package Apache / apache2'
    # tom is not apache maintainer
    page.wont_have_button 'Accept'

    logout
    login_fred to: request_show_path(requestid)
    find('#action_display_0').must_have_text 'Iggy Pop (Iggy) wants the role maintainer for package Apache / apache2'
    click_button 'Accept'

    # now check the role addition link is gone
    logout
    login_Iggy to: package_show_path(project: 'Apache', package: 'apache2')
    page.wont_have_link 'Request role addition'
  end

  def test_superseding_is_displayed_when_needed # spec/features/webui/requests_spec.rb
    # create testing superseded submission first
    login_tom to: package_show_path(project: 'Apache', package: 'apache2')
    click_link 'Submit package'
    fill_in 'targetproject', with: 'kde4'
    fill_in 'description', with: 'I want to see his reaction'
    click_button 'Ok'
    within '#flash-messages' do
      click_link 'submit request'
    end
    oldrequest = current_path.gsub(%r{\/request\/show\/(\d*)}, '\1').to_i
    # verify it is not superseding anything
    page.wont_have_text('Superseding')
    page.wont_have_field('supersede_request_numbers[]')

    # create submission that is superseding the former one
    visit package_show_path(project: 'Apache', package: 'apache2')
    click_link 'Submit package'
    fill_in 'targetproject', with: 'kde4'
    fill_in 'description', with: 'I want to see his reaction'
    page.must_have_field('supersede_request_numbers[]')
    all('input[name="supersede_request_numbers[]"]').each {|input| check(input[:id]) }
    click_button 'Ok'
    within '#flash-messages' do
      click_link 'submit request'
    end
    newrequest = current_path.gsub(%r{\/request\/show\/(\d*)}, '\1').to_i

    # Verify we know which pkg we superseded
    page.must_have_text('Supersedes')
    page.must_have_link(oldrequest)

    # Check if the superseded pkg knows which one is replacing it
    click_link oldrequest
    page.must_have_text('Superseded by')
    page.wont_have_text('Supersedes')
    page.must_have_link(newrequest)
  end

  def test_invalid_id_gives_error # spec/controllers/webui/request_controller_spec.rb
    login_Iggy
    visit request_show_path(20000)
    page.must_have_text("Can't find request 20000")
    page.must_have_text('Home of Iggy')
  end

  def test_submit_package_and_revoke # spec/features/webui/requests_spec.rb
    login_Iggy to: package_show_path(project: 'home:Iggy', package: 'TestPack')
    click_link 'Submit package'
    fill_in 'targetproject', with: 'home:tom'
    fill_in 'description', with: 'Want it?'
    click_button 'Ok'

    flash_message.must_match %r{Created submit request .* to home:tom}
    within '#flash-messages' do
      click_link 'submit request'
    end

    requestid = current_path.gsub(%r{\/request\/show\/(\d*)}, '\1').to_i

    # request view shows diff
    page.must_have_text '+Group: Group/Subgroup'

    # tab
    page.must_have_text 'My Decision'
    fill_in 'reason', with: 'Great work!'
    page.wont_have_selector 'input#accept_request_button'

    fill_in 'reason', with: 'Oops'
    click_button 'Revoke request'

    page.must_have_text 'Request revoked!'
    page.must_have_text "Request #{requestid} (revoked)"
    page.must_have_text "There's nothing to be done right now"
  end

  uses_transaction :test_tom_adds_invalid_project_reviewer
  def test_tom_adds_invalid_project_reviewer # spec/features/webui/requests_spec.rb
    login_tom to: user_show_path(user: 'tom')

    within('table#reviews_in_table') do
      page.must_have_text '~:branches:kde4 / BranchPack'
      first(:css, 'a.request_link').click
    end

    page.must_have_text 'Review for tom'

    click_link 'Add a review'
    page.must_have_text 'Add Reviewer'
    # test switching reviewer type
    find(:id, 'review_type').select('Project')
    page.must_have_text 'Project:'
    fill_in 'review_project', with: 'INVALID/PROJECT'
    click_button 'Ok'
    find('#flash-messages').must_have_text 'Unable add review to'
    page.must_have_text 'Open review for test_group'
  end

  uses_transaction :test_tom_adds_reviewer_Iggy
  def test_tom_adds_reviewer_Iggy # spec/features/webui/requests_spec.rb
    login_tom to: user_show_path(user: 'tom')

    within('table#reviews_in_table') do
      page.must_have_text '~:branches:kde4 / BranchPack'
      first(:css, 'a.request_link').click
    end

    page.must_have_text 'Review for tom'

    click_link 'Add a review'
    page.must_have_text 'Add Reviewer'
    # test switching reviewer type
    find(:id, 'review_type').select('Group')
    page.must_have_text 'Group:'
    fill_in 'review_group', with: 'test_group_b'
    click_button 'Ok'
    page.must_have_text 'Open review for test_group' # existed already
    page.must_have_text 'Open review for test_group_b' # added by us

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

  def test_request_4_can_expand # spec/features/webui/requests_spec.rb
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

  uses_transaction :test_add_submitter_as_maintainer
  def test_add_submitter_as_maintainer # spec/features/webui/requests_spec.rb
    use_js

    # Accept the request adding submitter
    login_king to: request_show_path(4)
    check('add_submitter_as_maintainer_0')
    click_button 'Accept request'
    find('#flash-messages').must_have_text 'Request 4 accepted'
    # Iggy should be a maintainer now
    visit package_users_path(project: 'Apache', package: 'BranchPack')
    find('#user-table').must_have_text '(Iggy)'
  end

  def visit_requests
    visit request_show_path(1)
    page.must_have_text 'Request 1'

    visit request_show_path(2)
    page.must_have_text 'Request 2'

    visit request_show_path(10)
    page.must_have_text 'Request 10'
  end

  def test_requests_display_as_nobody # spec/controllers/webui/request_controller_spec.rb
    visit_requests
  end

  def test_requests_display_as_king # spec/controllers/webui/request_controller_spec.rb
    login_king
    visit_requests
  end

  def test_requests # spec/controllers/webui/user_controller_spec.rb
    get "/users/requests.json"
    assert_response :success
    result = ActiveSupport::JSON.decode(@response.body)
    assert_equal "1", result["draw"]
    assert_equal "0", result["recordsTotal"]
    assert_equal [], result["data"]
  end

  def test_going_through_request_list
    use_js
    login_king

    visit project_requests_path(project: "Apache")
    page.must_have_text "Requests for Apache"
    find_all("a.request_link", count: 4)[1].click

    assert_equal "/request/show/1000", page.current_path
    # start of list
    page.wont_have_link("<<")
    click_link(">>")
    assert_equal "/request/show/10", page.current_path
    click_link(">>")
    assert_equal "/request/show/5", page.current_path
    click_link(">>")
    assert_equal "/request/show/4", page.current_path
    page.wont_have_link(">>")
    # end of list
    click_link("<<")
    assert_equal "/request/show/5", page.current_path
    click_link("<<")
    assert_equal "/request/show/10", page.current_path
    click_link(">>")
    assert_equal "/request/show/5", page.current_path
  end

  def test_succesful_comment_creation # spec/features/webui/comments_spec.rb
    login_Iggy to: request_show_path(1)
    fill_in 'comment_body', with: 'Comment Body'
    find_button('Add comment').click
    find('#flash-messages').must_have_text 'Comment was successfully created.'
  end

  def test_can_not_accept_own_requests # spec/features/webui/requests_spec.rb
    login_tom to: package_show_path(project: 'Apache', package: 'apache2')
    click_link 'Submit package'
    fill_in 'targetproject', with: 'kde4'
    fill_in 'description', with: 'I want to see his reaction'
    click_button 'Ok'

    assert_equal package_show_path(project: 'Apache', package: 'apache2'), page.current_path
    assert page.has_content?(/Created submit request \d+ to kde4/)
    within '#flash-messages' do
      click_link 'submit request'
    end

    # request history
    page.must_have_text %r{created request.*now}
    page.must_have_selector 'input#revoke_request_button'
    page.wont_have_selector 'input#accept_request_button'
  end

  def test_succesful_reply_comment_creation # spec/features/webui/comments_spec.rb
    login_Iggy to: request_show_path(4)
    find(:id, 'reply_link_id_301').click
    fill_in 'reply_body_301', with: 'Comment Body'
    find(:id, 'add_reply_301').click
    find('#flash-messages').must_have_text 'Comment was successfully created.'
  end

  def verify_email(fixture_name, myid, email)
    should = load_fixture("event_mailer/#{fixture_name}").gsub('REQUESTID', myid).chomp
    lines = email.encoded.lines.map(&:chomp).select { |l| l !~ %r{^Date:} }
    lines.select! { |l| l !~ %r{^ boundary=} }
    lines.select! { |l| l !~ %r{^----==_mimepart} }
    assert_equal should, lines.join("\n")
  end

  def test_comment_event # spec/mailers/event_mailer_spec.rb
    login_tom to: request_show_path(4)

    # adrian is reviewer, Iggy creator, Admin (fixture) commenter
    # tom is commenter *and* author, so doesn't get mail
    SendEventEmails.new.perform
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      fill_in 'comment_body', with: 'Comment Body'
      find_button('Add comment').click
      page.must_have_text 'Comment Body'
      SendEventEmails.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal 'Request 4 commented by tom (submit Apache/BranchPack)', email.subject
    verify_email('comment_event', '4', email)

    # now check the commenters get no more mails too if unsubscribed
    EventSubscription.where(eventtype: 'Event::CommentForRequest', receiver_role: :commenter).delete_all

    ActionMailer::Base.deliveries.clear

    # adrian is reviewer, Iggy creator, Admin (fixture) commenter
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      fill_in 'comment_body', with: 'Another Body'
      find_button('Add comment').click
      page.must_have_text 'Another Body'
      SendEventEmails.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal 'Request 4 commented by tom (submit Apache/BranchPack)', email.subject
    verify_email('another_comment_event', '4', email)
  end
end
