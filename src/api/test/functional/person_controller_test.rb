require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class PersonControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    reset_auth
  end

  def test_index
    get '/person/'
    assert_response :unauthorized

    login_adrian
    get '/person'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'unconfirmed_user' }

    get '/person?confirmed=1'
    assert_response :success
    assert_no_xml_tag tag: 'entry', attributes: { name: 'unconfirmed_user' }

    get '/person/'
    assert_response :success

    get '/person?prefix=s'
    assert_response :success
  end

  def test_ichain
    login_adrian
    get '/person/tom', headers: { 'username' => 'fred' }
    assert_response :success
  end

  def test_userinfo_for_valid_http_user
    login_adrian
    get '/person/tom'
    assert_response :success
    # This returns the xml content with the user info
  end

  def test_userinfo_for_deleted_user
    login_adrian
    # it exists
    user = User.find_by_login('deleted')
    assert_not_nil user
    assert_equal user.state, 'deleted'
    # but is not visible since it is tagged as deleted
    get '/person/deleted'
    assert_response :not_found
  end

  def test_userinfo_from_param_valid
    login_adrian
    get '/person/fred'
    assert_response :success
  end

  def test_userinfo_from_param_invalid
    login_adrian
    get '/person/notfred'
    assert_response :not_found
  end

  def test_userinfo_with_empty_auth_header
    get '/person/tom'
    assert_response :unauthorized
  end

  def test_userinfo_with_broken_auth_header
    prepare_request_invalid_user
    get '/person/tom'
    assert_select 'status[code] > summary', /^Unknown user '[^']+' or invalid password$/

    assert_response :unauthorized
  end

  def test_watchlist_privacy
    prepare_request_valid_user

    get '/person/tom'
    # should see their watchlist
    assert_xml_tag tag: 'person', child: { tag: 'watchlist' }

    get '/person/fred'
    # should not see that watchlist
    assert_no_xml_tag tag: 'person', child: { tag: 'watchlist' }
  end

  def test_watchlist_with_admin_user
    project_names = ['Apache', 'BaseDistro3', 'Devel:BaseDistro:Update', 'home:Iggy']
    package_names = %w[Tidy TestPack]
    request_numbers = %w[1000 4]
    user = User.find_by(login: 'tom')
    project_names.each do |name|
      user.watched_items << WatchedItem.create(watchable: Project.find_by!(name: name), user: user)
    end
    package_names.each do |name|
      user.watched_items << WatchedItem.create(watchable: Package.find_by!(name: name), user: user)
    end
    request_numbers.each do |number|
      user.watched_items << WatchedItem.create(watchable: BsRequest.find_by!(number: number), user: user)
    end
    user.save!

    prepare_request_with_user('king', 'sunflower')
    get '/person/tom'
    assert_response :success
    assert_select 'person' do
      assert_select 'watchlist' do
        assert_select 'project', name: 'Apache'
        assert_select 'project', name: 'BaseDistro3'
        assert_select 'project', name: 'home:Iggy'
        assert_select 'package', name: 'Tidy', project: 'Apache'
        assert_select 'package', name: 'TestPack', project: 'home:Iggy'
        assert_select 'request', number: '1000'
        assert_select 'request', number: '4'
      end
    end
  end

  def test_update_watchlist
    user_tom = User.find_by(login: 'tom')

    xml = <<~XML
      <person>
      <login>tom</login>
      <email>tschmidt@example.com</email>
      <realname>Thommy Cool</realname>
      <state>confirmed</state>
      <watchlist>
      <project name="home:tom"/>
      <project name="BaseDistro3"/>
      <project name="Apache"/>
      <package name="Tidy" project="Apache"/>
      </watchlist>
      </person>
    XML

    prepare_request_valid_user
    put '/person/tom', params: xml
    assert_response :success
    assert_select 'status', code: 'ok' do
      assert_select 'summary', 'Ok'
    end

    assert_equal ['Apache', 'BaseDistro3', 'home:tom'],
                 Project.includes(:watched_items).where(watched_items: { user: user_tom }).pluck(:name).sort
    assert_equal ['Tidy'],
                 Package.includes(:watched_items).where(watched_items: { user: user_tom }).pluck(:name).sort

    xml = <<~XML
      <person>
      <login>tom</login>
      <email>tschmidt@example.com</email>
      <realname>Thommy Cool</realname>
      <state>confirmed</state>
      <watchlist>
      <project name="BaseDistro3"/>
      <project name="home:Iggy"/>
      <project name="Apache"/>
      <project name="Devel:BaseDistro:Update"/>
      <package name="apache2" project="Apache"/>
      <package name="pack2" project="BaseDistro3"/>
      <request number="1000"/>
      </watchlist>
      </person>
    XML

    prepare_request_valid_user
    put '/person/tom', params: xml
    assert_response :success
    assert_select 'status', code: 'ok' do
      assert_select 'summary', 'Ok'
    end
    assert_equal ['Apache', 'BaseDistro3', 'Devel:BaseDistro:Update', 'home:Iggy'],
                 Project.includes(:watched_items).where(watched_items: { user: user_tom }).pluck(:name).sort
    assert_equal %w[apache2 pack2],
                 Package.includes(:watched_items).where(watched_items: { user: user_tom }).pluck(:name).sort
    assert_equal [1000],
                 BsRequest.includes(:watched_items).where(watched_items: { user: user_tom }).pluck(:number).sort

    # When trying to watch a non-existing project, it's simply ignored
    xml = <<~XML
      <person>
      <login>tom</login>
      <email>tschmidt@example.com</email>
      <realname>Thommy Cool</realname>
      <state>confirmed</state>
      <watchlist>
      <project name="BaseDistro3"/>
      <project name="NonExistingProject"/>
      </watchlist>
      </person>
    XML

    prepare_request_valid_user
    put '/person/tom', params: xml
    assert_response :success
    assert_select 'status', code: 'ok' do
      assert_select 'summary', 'Ok'
    end
    assert_equal ['BaseDistro3'],
                 Project.includes(:watched_items).where(watched_items: { user: user_tom }).pluck(:name).sort
  end

  def test_update_user_info
    prepare_request_valid_user

    # get original data
    get '/person/tom'
    assert_response :success

    # change the xml data set that came as response body
    new_name = 'Thommy Cool'
    userinfo_xml = @response.body
    doc = REXML::Document.new(userinfo_xml)
    doc.elements['//realname'].text = new_name
    doc.elements['//watchlist'].add_element 'project'
    doc.elements['//project'].add_attribute(REXML::Attribute.new('name', 'home:tom'))
    r = REXML::Element.new('globalrole')
    r.text = 'Admin'
    doc.elements['/person'].insert_after(doc.elements['//state'], r)
    # Write changed data back and validate result
    prepare_request_valid_user
    put '/person/tom', params: doc.to_s
    assert_response :success
    get '/person/tom'
    assert_response :success
    assert_xml_tag tag: 'realname', content: new_name
    assert_xml_tag tag: 'project', attributes: { name: 'home:tom' }
    assert_xml_tag tag: 'state', content: 'confirmed'
    assert_no_xml_tag tag: 'globalrole', content: 'Admin' # written as non-Admin

    # write as admin
    login_king
    put '/person/tom', params: doc.to_s
    assert_response :success
    get '/person/tom'
    assert_response :success
    assert_xml_tag tag: 'globalrole', content: 'Admin' # written as Admin

    # revert
    doc.elements['/person'].delete_element 'globalrole'
    put '/person/tom', params: doc.to_s
    assert_response :success
    get '/person/tom'
    assert_response :success
    assert_no_xml_tag tag: 'globalrole', content: 'Admin'

    # remove watchlist item
    doc.elements['//watchlist'].delete_element 'project'
    put '/person/tom', params: doc.to_s
    assert_response :success
    get '/person/tom'
    assert_response :success
    assert_no_xml_tag tag: 'project', attributes: { name: 'home:tom' }

    login_adrian
    put '/person/tom', params: doc.to_s
    assert_response :forbidden

    login_king
    put '/person/tom', params: doc.to_s
    assert_response :success

    # lock user
    doc.elements['//state'].text = 'locked'
    put '/person/tom', params: doc.to_s
    assert_response :success
    get '/person/tom'
    assert_response :success
    assert_xml_tag tag: 'state', content: 'locked'
    prepare_request_valid_user
    put '/person/tom', params: doc.to_s
    assert_response :forbidden
    # set back
    login_king
    doc.elements['//state'].text = 'confirmed'
    put '/person/tom', params: doc.to_s
    assert_response :success

    # create new user
    put '/person/new_user', params: doc.to_s
    assert_response :success
    get '/person/new_user'
    assert_response :success
    put '/person/new_user', params: doc.to_s
    assert_response :success
    # cleanup
    User.session = User.find_by(login: 'new_user')
    Project.find_by(name: 'home:new_user').destroy

    # check global role
    get '/person/king'
    assert_response :success
    assert_xml_tag tag: 'person', child: { tag: 'globalrole', content: 'Admin' }

    # refetch the user info if the name has really change
    prepare_request_valid_user
    get '/person/tom'
    assert_xml_tag tag: 'person', child: { tag: 'realname', content: new_name }
    assert_no_xml_tag tag: 'person', child: { tag: 'globalrole', content: 'Admin' }
  end

  def test_create_subaccount
    login_king

    user_xml = "<person>
  <login>lost_guy</login>
  <email>lonely_person@universe.com</email>
  <realname>The Other Person</realname>
  <owner userid='adrian'/>
</person>"

    # create new user
    put '/person/lost_guy', params: user_xml
    assert_response :success

    get '/person/lost_guy'
    assert_response :success
    assert_xml_tag tag: 'owner', attributes: { userid: 'adrian' }

    lost_guy = User.find_by_login!('lost_guy')
    assert_equal 'subaccount', lost_guy[:state]
    assert_equal 'confirmed', lost_guy.state

    user_xml = "<person>
  <login>lost_guy2</login>
  <email>lonely_person@universe.com</email>
  <realname>The Other Guy</realname>
  <owner userid='lost_guy'/>
</person>"

    # no account chaining
    put '/person/lost_guy2', params: user_xml
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'subaccount_chaining' }
  end

  def test_lock_user
    login_king

    user_xml = "<person>
  <login>lost_guy</login>
  <email>lonely_person@universe.com</email>
  <realname>The Other Guy</realname>
  <state>confirmed</state>
</person>"

    # create new user
    put '/person/lost_guy', params: user_xml
    assert_response :success

    # create sub project of home
    put '/source/home:lost_guy:subproject/_meta', params: '<project name="home:lost_guy:subproject"><title/><description/></project>'
    assert_response :success

    # only admins, not even the user itself can lock himself
    login_Iggy
    post '/person/lost_guy?cmd=lock'
    assert_response :forbidden
    post '/person/lost_guy?cmd=delete'
    assert_response :forbidden

    # verify data exists
    lost_guy = User.find_by(login: 'lost_guy')
    assert_equal 'lonely_person@universe.com', lost_guy.email
    assert_equal 'The Other Guy', lost_guy.realname

    # but the admin can ...
    login_king
    post '/person/lost_guy?cmd=lock'
    assert_response :success
    get '/person/lost_guy'
    assert_response :success
    assert_xml_tag tag: 'state', content: 'locked'
    get '/source/home:lost_guy:subproject/_meta'
    assert_response :success
    assert_xml_tag tag: 'lock'
    get '/source/home:lost_guy/_meta'
    assert_response :success
    assert_xml_tag tag: 'lock'

    # we can still delete the locked user
    post '/person/lost_guy?cmd=delete'
    assert_response :success
    get '/person/lost_guy'
    assert_response :not_found
    get '/source/home:lost_guy:subproject/_meta'
    assert_response :not_found
    get '/source/home:lost_guy/_meta'
    assert_response :not_found

    # delete has removed the right user data, but entry is still there
    lost_guy = User.find_by(login: 'lost_guy')
    assert_equal 'deleted', lost_guy.state
    assert_equal '', lost_guy.email
    assert_equal '', lost_guy.realname
  end

  def test_register_disabled
    c = ::Configuration.first
    c.registration = 'deny'
    c.save!
    data = '<unregisteredperson>
              <login>adrianSuSE</login>
              <email>adrian@example.com</email>
              <realname>Adrian Schroeter</realname>
              <password>so_alone</password>
            </unregisteredperson>'
    post '/person?cmd=register', params: data
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'err_register_save' }
    assert_xml_tag tag: 'summary', content: 'Sorry, sign up is disabled'
  end

  def test_register_confirmation
    c = ::Configuration.first
    c.registration = 'confirmation'
    c.save!
    data = '<unregisteredperson>
              <login>adrianSuSE</login>
              <email>adrian@example.com</email>
              <realname>Adrian Schroeter</realname>
              <password>so_alone</password>
              <state>confirmation</state>
            </unregisteredperson>'
    post '/person?cmd=register', params: data
    assert_response :bad_request
    assert_xml_tag tag: 'status', attributes: { code: 'err_register_save' }
    assert_xml_tag tag: 'summary', content: 'Thank you for signing up! An admin has to confirm your account now. Please be patient.'

    # we tried to register as confirmed up there, ensure that we are not...
    login_king
    get '/person/adrianSuSE'
    assert_response :success
    assert_xml_tag tag: 'state', content: 'unconfirmed'
  end

  def test_register_and_change_password_new_way
    data = '<unregisteredperson>
              <login>adrianSuSE</login>
              <email>adrian@example.com</email>
              <realname>Adrian Schroeter</realname>
              <state>locked</state>
              <password>so_alone</password>
            </unregisteredperson>'
    post '/person?cmd=register', params: data
    assert_response :success

    u = User.find_by_login('adrianSuSE')
    assert_not_nil u
    assert_equal 'adrianSuSE', u.login
    assert_equal 'adrian@example.com', u.email
    assert_equal 'Adrian Schroeter', u.realname
    assert_nil u.adminnote

    # change password
    data = 'NEWPASSW0RD'
    post '/person/adrianSuSE?cmd=change_password', params: data
    assert_response :unauthorized

    # wrong user
    login_adrian
    post '/person/adrianSuSE?cmd=change_password', params: data
    assert_response :forbidden
    assert_xml_tag tag: 'status', attributes: { code: 'update_user_not_authorized' }

    # admin
    login_king
    post '/person/adrianSuSE?cmd=change_password', params: ''
    assert_response :not_found
    assert_xml_tag tag: 'status', attributes: { code: 'password_empty' }

    post '/person/adrianSuSE?cmd=change_password', params: data
    assert_response :success
    # test login with new password
    prepare_request_with_user('adrianSuSE', data)
    get '/person/adrianSuSE'
    assert_response :success

    # cleanup
    u.destroy
  end

  def test_register_old_way
    data = '<unregisteredperson>
              <login>adrianSuSE</login>
              <email>adrian@example.com</email>
              <realname>Adrian Schroeter</realname>
              <state>locked</state>
              <password>so_alone</password>
              <note>I do not trust this guy, this note is only allowed to be stored by admin</note>
            </unregisteredperson>'
    # FIXME3.0: to be removed
    post '/person/register', params: data
    assert_response :success

    u = User.find_by_login('adrianSuSE')
    assert_not_nil u
    assert_equal u.login, 'adrianSuSE'
    assert_equal u.email, 'adrian@example.com'
    assert_equal u.realname, 'Adrian Schroeter'
    assert_nil u.adminnote
    User.session = u
    Project.find_by(name: 'home:adrianSuSE').destroy
    u.destroy
  end
end
