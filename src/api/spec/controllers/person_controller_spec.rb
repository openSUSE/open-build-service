RSpec.describe PersonController do
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  shared_examples 'not allowed to change user details' do
    it 'sets an error code' do
      subject
      expect(response.header['X-Opensuse-Errorcode']).to eq('change_userinfo_no_permission')
    end

    it 'does not change users real name' do
      expect { subject }.not_to(change(user, :realname))
    end

    it 'does not change users email address' do
      expect { subject }.not_to(change(user, :email))
    end
  end

  describe 'GET #userinfo' do
    context 'called by a user' do
      before do
        login user
        get :userinfo, params: { login: user.login }
      end

      it { expect(response.body).to have_css('person > login', text: user.login) }
      it { expect(response.body).to have_css('person > email', text: user.email) }
      it { expect(response.body).to have_css('person > realname', text: user.realname) }
      it { expect(response.body).to have_css('person > state', text: 'confirmed') }

      it 'shows not the ignore_auth_services flag' do
        expect(response.body).to have_css('person > ignore_auth_services', text: user.ignore_auth_services, count: 0)
      end
    end

    context 'called by an admin' do
      before do
        login admin_user
        get :userinfo, params: { login: user.login }
      end

      it { expect(response.body).to have_css('person > login', text: user.login) }
      it { expect(response.body).to have_css('person > email', text: user.email) }
      it { expect(response.body).to have_css('person > realname', text: user.realname) }
      it { expect(response.body).to have_css('person > state', text: 'confirmed') }

      it 'shows not the ignore_auth_services flag' do
        expect(response.body).to have_css('person > ignore_auth_services', text: user.ignore_auth_services, count: 0)
      end
    end
  end

  describe 'POST #post_userinfo' do
    let!(:old_password_digest) { user.password_digest }

    before do
      login user
    end

    context 'when using default authentication' do
      before do
        request.env['RAW_POST_DATA'] = 'password_has_changed'
        post :post_userinfo, params: { login: user.login, cmd: 'change_password', format: :xml }
      end

      it 'changes the password' do
        expect(old_password_digest).not_to eq(user.reload.password_digest)
      end
    end
  end

  describe 'PUT #put_userinfo' do
    let(:xml) do
      <<-XML_DATA
        <userinfo>
          <realname>test-user</realname>
          <email>test-user@email.com</email>
          <watchlist>
            <project name="test-proj"/>
            <package name="test-pkg" project="test-proj"/>
            <request number="#{delete_request.number}"/>
          </watchlist>
        </userinfo>
      XML_DATA
    end

    let(:delete_request) { create(:delete_bs_request) }

    context 'when watchlist is available in xml' do
      let(:test_user) { create(:confirmed_user, login: 'test-user', email: 'test-user@email.com') }
      let(:project) { create(:project, name: 'test-proj') }
      let!(:package) { create(:package, project: project, name: 'test-pkg') }

      before do
        login admin_user
        put :put_userinfo, params: { login: test_user.login, format: :xml }, body: xml
      end

      it "adds projects, requests and packages to user's watchlist" do
        expect(test_user.watched_items.count).to eq(3)
        expect(test_user.watched_items.collect(&:watchable)).to include(project, package, delete_request)
      end
    end
  end

  describe 'GET #watchlist' do
    context 'user logged-in' do
      let(:xml) do
        <<-XML_DATA
          <watchlist>
            <project name="test-proj"/>
            <package name="test-pkg" project="test-proj"/>
            <request number="#{delete_request.number}"/>
          </watchlist>
        XML_DATA
      end

      let(:project) { create(:project, name: 'test-proj') }
      let(:package) { create(:package, project: project, name: 'test-pkg') }
      let(:delete_request) { create(:delete_bs_request) }

      before do
        user.watched_items.create(watchable: project)
        user.watched_items.create(watchable: package)
        user.watched_items.create(watchable: delete_request)
        login user

        get :watchlist, params: { login: user.login }
      end

      it 'returns watchlist' do
        expect(Xmlhash.parse(response.body)).to eq(Xmlhash.parse(xml))
      end
    end
  end

  describe 'PUT #put_watchlist' do
    context 'creates watchlist' do
      let(:xml) do
        <<-XML_DATA
          <watchlist>
            <project name="test-proj"/>
            <package name="test-pkg" project="test-proj"/>
            <request number="#{delete_request.number}"/>
          </watchlist>
        XML_DATA
      end

      let!(:project) { create(:project, name: 'test-proj') }
      let!(:package) { create(:package, project: project, name: 'test-pkg') }
      let(:delete_request) { create(:delete_bs_request) }

      before do
        login user
        put :put_watchlist, params: { login: user.login, format: :xml }, body: xml
      end

      it "adds projects, packages and requests to user's watchlist" do
        expect(user.watched_items.count).to eq(3)
        expect(user.watched_items.collect(&:watchable)).to include(project, package, delete_request)
      end
    end
  end
end
