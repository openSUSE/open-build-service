# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  let(:admin_user) { create(:admin_user, login: 'king') }
  let(:user) { create(:user, login: 'eisendieter') }
  let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
  let(:user_belongs_to_confirmed_owner) { create(:user, owner: confirmed_user) }
  let(:user_belongs_to_unconfirmed_owner) { create(:confirmed_user, owner: user) }
  let(:input) { { 'Event::RequestCreate' => { source_maintainer: '1' } } }
  let(:project_with_package) { create(:project_with_package, name: 'project_b') }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:login).with_message('must be given') }
    it { is_expected.to validate_length_of(:login).is_at_least(2).with_message('must have more than two characters') }
    it { is_expected.to validate_length_of(:login).is_at_most(100).with_message('must have less than 100 characters') }
    it { is_expected.to validate_inclusion_of(:state).in_array(User::STATES) }

    it { is_expected.to allow_value('king@opensuse.org').for(:email) }
    it { is_expected.not_to allow_values('king.opensuse.org', 'opensuse.org', 'opensuse').for(:email) }

    it { expect(user.state).to eq('unconfirmed') }

    it { expect(create(:user)).to validate_uniqueness_of(:login).with_message('is the name of an already existing user') }
  end

  describe '#is_active?' do
    it 'returns true if user is confirmed' do
      expect(confirmed_user.is_active?).to be_truthy
    end

    it 'returns false if user is NOT confirmed' do
      expect(user.is_active?).to be_falsey
    end

    context 'when user has owner' do
      it 'returns true if owner is confirmed' do
        expect(user_belongs_to_confirmed_owner.is_active?).to be_truthy
      end

      it 'returns false if owner not confirmed' do
        expect(user_belongs_to_unconfirmed_owner.is_active?).to be_falsey
      end
    end
  end

  describe '#find_by_login!' do
    it 'returns a user if it exists' do
      expect(User.find_by_login!(user.login)).to eq user
    end

    it 'raises an exception if user does not exist' do
      expect { User.find_by_login!('foo') }.to raise_error(NotFoundError, "Couldn't find User with login = foo")
    end
  end

  describe '#can_modify_user?' do
    it { expect(admin_user.can_modify_user?(confirmed_user)).to be true }
    it { expect(user.can_modify_user?(confirmed_user)).to be false }
    it { expect(user.can_modify_user?(user)).to be true }
  end

  describe 'user creation' do
    it "sets the 'last_logged_in_at' attribute" do
      user = User.new
      expect(user.last_logged_in_at).to be nil
      user.save
      expect(user.last_logged_in_at).to be_within(30.seconds).of(Time.now)
    end
  end

  describe 'home project creation' do
    it 'creates a home project by default if allow_user_to_create_home_project is enabled' do
      allow(Configuration).to receive(:allow_user_to_create_home_project).and_return(true)
      user = create(:confirmed_user, login: 'random_name')
      expect(user.home_project).not_to be_nil
    end

    it "doesn't creates a home project if allow_user_to_create_home_project is disabled" do
      allow(Configuration).to receive(:allow_user_to_create_home_project).and_return(false)
      user = create(:confirmed_user, login: 'another_random_name')
      expect(user.home_project).to be_nil
    end
  end

  describe "methods used in the User's dashboard" do
    let(:project) { create(:project, name: 'project_a') }

    it 'will have involved packages' do
      create(:relationship_package_user, package: project_with_package.packages.first, user: user)
      expect(user.involved_packages).to include(project_with_package.packages.first)
    end

    it 'will have involved projects' do
      create(:relationship_project_user, project: project, user: user)
      create(:relationship_project_user, project: project_with_package, user: user)
      involved_projects = user.involved_projects
      expect(involved_projects).to include(user.home_project)
      expect(involved_projects).to include(project)
      expect(involved_projects).to include(project_with_package)
    end

    it 'will have owned projects and packages' do
      create(:attrib, attrib_type: AttribType.find_by(name: 'OwnerRootProject'), project: project_with_package)
      create(:relationship_package_user, package: project_with_package.packages.first, user: user)
      create(:relationship_project_user, project: project_with_package, user: user)
      owned_packages = user.owned_packages
      expect(owned_packages[0]).to eq([nil, project_with_package.name])
      expect(owned_packages[1]).to eq([project_with_package.packages.first.name, project_with_package.name])
    end
  end

  describe 'create_user_with_fake_pw!' do
    context 'with login and email' do
      let(:user) { User.create_user_with_fake_pw!(login: 'tux', email: 'some@email.com') }

      it 'creates a user with a fake password' do
        expect(user.password).not_to eq(User.create_user_with_fake_pw!(login: 'tux2', email: 'some@email.com').password)
      end

      it 'creates a user from given attributes' do
        expect(user).to be_an(User)
        expect(user.login).to eq('tux')
        expect(user.email).to eq('some@email.com')
      end
    end

    context 'without params' do
      it 'throws an exception' do
        expect { User.create_user_with_fake_pw! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#add_globalrole' do
    before do
      user.update_globalroles(Role.where(title: 'Staff'))
      user.add_globalrole(Role.where(title: 'Admin'))
    end

    it 'adds a global role' do
      expect(user.roles).to include(Role.find_by(title: 'Admin'))
    end

    it 'keeps old global roles' do
      expect(user.roles).to include(Role.find_by(title: 'Staff'))
    end
  end

  describe '#involved_packages' do
    let(:group) { create(:group) }
    let!(:groups_user) { create(:groups_user, user: confirmed_user, group: group) }

    let(:maintained_package) { create(:package) }
    let!(:relationship_package_user) { create(:relationship_package_user, user: confirmed_user, package: maintained_package) }

    let(:group_maintained_package) { create(:package) }
    let!(:relationship_package_group) { create(:relationship_package_group, group: group, package: group_maintained_package) }

    let(:project_maintained_package) { create(:package) }
    let!(:relationship_project_user) { create(:relationship_project_user, user: confirmed_user, project: project_maintained_package.project) }

    let(:group_project_maintained_package) { create(:package) }
    let!(:relationship_project_group) { create(:relationship_project_group, group: group, project: group_project_maintained_package.project) }

    subject { confirmed_user.involved_packages }

    it 'does include packages where user is maintainer' do
      expect(subject).to include(maintained_package)
    end

    it 'does include packages where user is maintainer by group' do
      expect(subject).to include(group_maintained_package)
    end

    it 'does not include packages where user is maintainer of the project' do
      expect(subject).not_to include(project_maintained_package)
    end

    it 'does not include packages where user is maintainer of the project by group' do
      expect(subject).not_to include(group_project_maintained_package)
    end
  end

  describe '#involved_reviews' do
    shared_examples 'involved_reviews' do
      subject { confirmed_user.involved_reviews }

      before do
        # Setting state in create will be overwritten by BsRequest#sanitize!
        # so we need to set it to review afterwards
        [subject_request, request_with_same_creator_and_reviewer, request_of_another_subject].each do |request|
          request.state = :review
          request.save
        end
      end

      it 'returns an ActiveRecord::Relation of bs requests' do
        expect(subject).to be_a_kind_of(ActiveRecord::Relation)
        subject.each do |item|
          expect(item).to be_instance_of(BsRequest)
        end
      end

      it 'does include reviews where the user is not the creator of the request' do
        expect(subject).to include(subject_request)
      end

      it 'does not include reviews where the user is the creator of the request' do
        expect(subject).not_to include(request_with_same_creator_and_reviewer)
      end

      it 'does not include reviews where the user is not the reviewer' do
        expect(subject).not_to include(request_of_another_subject)
      end
    end

    context 'with by_user reviews' do
      it_behaves_like 'involved_reviews' do
        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_user: confirmed_user.login, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) do
          create(:review, by_user: confirmed_user.login, bs_request: request_with_same_creator_and_reviewer)
        end

        let(:other_project) { create(:project) }
        let(:request_of_another_subject) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_of_another_subject) { create(:review, by_user: admin_user.login, bs_request: request_of_another_subject) }
      end
    end

    context 'with by_group reviews' do
      it_behaves_like 'involved_reviews' do
        let(:group) { create(:group) }
        let!(:groups_user) { create(:groups_user, user: confirmed_user, group: group) }

        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_group: group.title, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) { create(:review, by_group: group.title, bs_request: request_with_same_creator_and_reviewer) }

        let(:other_group) { create(:group) }
        let(:request_of_another_subject) { create(:bs_request, creator: admin_user.login) }
        let!(:review_of_another_subject) { create(:review, by_group: other_group.title, bs_request: request_of_another_subject) }
      end
    end

    context 'with by_project reviews' do
      it_behaves_like 'involved_reviews' do
        let(:project) { create(:project) }
        let!(:relationship_project_user) { create(:relationship_project_user, user: confirmed_user, project: project) }

        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_project: project.name, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) { create(:review, by_project: project.name, bs_request: request_with_same_creator_and_reviewer) }

        let(:other_project) { create(:project) }
        let(:request_of_another_subject) { create(:bs_request, creator: admin_user.login) }
        let!(:review_of_another_subject) { create(:review, by_project: other_project.name, bs_request: request_of_another_subject) }
      end
    end

    context 'with by_package reviews' do
      it_behaves_like 'involved_reviews' do
        let(:package) { create(:package) }
        let!(:relationship_package_user) { create(:relationship_package_user, user: confirmed_user, package: package) }

        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_project: package.project.name, by_package: package.name, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) do
          create(:review, by_project: package.project.name, by_package: package.name, bs_request: request_with_same_creator_and_reviewer)
        end

        let(:other_package) { create(:package) }
        let(:request_of_another_subject) { create(:bs_request, creator: admin_user.login) }
        let!(:review_of_another_subject) do
          create(:review, by_project: other_package.project.name, by_package: other_package.name, bs_request: request_of_another_subject)
        end

        let!(:relationship_project_user) { create(:relationship_project_user, user: admin_user, project: package.project) }
        it 'show the reviews for project maintainer' do
          expect(admin_user.involved_reviews).to include(request_with_same_creator_and_reviewer)
        end
      end
    end

    context 'with search parameter' do
      let(:request) { create(:bs_request, creator: admin_user.login) }
      let!(:review) { create(:review, by_user: confirmed_user.login, bs_request: request) }

      before do
        # Setting state in create will be overwritten by BsRequest#sanitize!
        # so we need to set it to review afterwards
        request.state = :review
        request.save
      end

      it 'returns the request if the search does match' do
        expect(confirmed_user.involved_reviews(admin_user.login)).to include(request)
      end

      it 'returns no request if the search does not match' do
        expect(confirmed_user.involved_reviews('does not exist')).not_to include(request)
      end
    end
  end

  describe '#combined_rss_feed_items' do
    let(:max_items_per_user) { Notification::RssFeedItem::MAX_ITEMS_PER_USER }
    let(:max_items_per_group) { Notification::RssFeedItem::MAX_ITEMS_PER_GROUP }
    let(:group) { create(:group) }
    let!(:groups_user) { create(:groups_user, user: confirmed_user, group: group) }

    context 'with a lot notifications from the user' do
      before do
        create_list(:rss_notification, max_items_per_group, subscriber: group)
        create_list(:rss_notification, max_items_per_user + 5, subscriber: confirmed_user)
        create_list(:rss_notification, 3, subscriber: user)
      end

      subject { confirmed_user.combined_rss_feed_items }

      it { expect(subject.count).to be(max_items_per_user) }
      it { expect(subject.any? { |x| x.subscriber != confirmed_user }).to be_falsey }
      it { expect(subject.any? { |x| x.subscriber == group }).to be_falsey }
      it { expect(subject.any? { |x| x.subscriber == user }).to be_falsey }
    end

    context 'with a lot notifications from the group' do
      before do
        create_list(:rss_notification, 5, subscriber: confirmed_user)
        create_list(:rss_notification, max_items_per_group - 1, subscriber: group)
        create_list(:rss_notification, 3, subscriber: user)
      end

      subject { confirmed_user.combined_rss_feed_items }

      it { expect(subject.count).to be(max_items_per_user) }
      it { expect(subject.select { |x| x.subscriber == confirmed_user }.length).to eq(1) }
      it { expect(subject.select { |x| x.subscriber == group }.length).to eq(max_items_per_user - 1) }
      it { expect(subject.any? { |x| x.subscriber == user }).to be_falsey }
    end

    context 'with a notifications mixed' do
      let(:batch) { max_items_per_user / 4 }

      before do
        create_list(:rss_notification, max_items_per_user + batch, subscriber: confirmed_user)
        create_list(:rss_notification, batch, subscriber: group)
        create_list(:rss_notification, batch, subscriber: confirmed_user)
        create_list(:rss_notification, batch, subscriber: group)
        create_list(:rss_notification, 3, subscriber: user)
      end

      subject { confirmed_user.combined_rss_feed_items }

      it { expect(subject.count).to be(max_items_per_user) }
      it { expect(subject.select { |x| x.subscriber == confirmed_user }.length).to be >= batch * 2 }
      it { expect(subject.select { |x| x.subscriber == group }.length).to eq(batch * 2) }
      it { expect(subject.any? { |x| x.subscriber == user }).to be_falsey }
    end
  end

  shared_examples 'password comparison' do
    context 'with invalid credentials' do
      it 'returns false' do
        expect(user.authenticate('invalid_password')).to eq(false)
      end
    end

    context 'with valid credentials' do
      it 'returns a user object for valid credentials' do
        expect(user.authenticate('buildservice')).to eq(user)
      end
    end
  end

  describe '#authenticate' do
    context 'as a user which has a deprecated password' do
      let(:user) { create(:user_deprecated_password) }

      context 'conversation of deprecated password' do
        before do
          user.authenticate('buildservice')
        end

        it 'converts the password to bcrypt' do
          expect(BCrypt::Password.new(user.password_digest).is_password?('buildservice')).to be_truthy
        end

        it 'resets the hash of the deprecated password' do
          expect(user.deprecated_password).to be(nil)
        end

        it 'resets the hash type of the deprecated password' do
          expect(user.deprecated_password_hash_type).to be(nil)
        end

        it 'resets the salt of the deprecated password' do
          expect(user.deprecated_password_salt).to be(nil)
        end
      end

      it_behaves_like 'password comparison'
    end

    context 'as a user which has a bcrypt password' do
      it_behaves_like 'password comparison'
    end
  end

  describe '.mark_login!' do
    before do
      user.update_attributes!(login_failure_count: 7, last_logged_in_at: 3.hours.ago)
      user.mark_login!
    end

    it "updates the 'last_logged_in_at'" do
      expect(user.last_logged_in_at).to be > 30.seconds.ago
    end

    it "resets the 'login_failure_count'" do
      expect(user.reload.login_failure_count).to eq 0
    end
  end

  describe '#find_with_credentials' do
    let(:user) { create(:user, login: 'login_test', login_failure_count: 7, last_logged_in_at: 3.hours.ago) }

    context 'when user exists' do
      subject { User.find_with_credentials(user.login, 'buildservice') }

      it { is_expected.to eq user }
      it { expect(subject.login_failure_count).to eq 0 }
      it { expect(subject.last_logged_in_at).to be > 30.seconds.ago }
    end

    context 'when user does not exist' do
      it { expect(User.find_with_credentials('unknown', 'buildservice')).to be nil }
    end

    context 'when user exist but password was incorrect' do
      subject! { User.find_with_credentials(user.login, '_buildservice') }

      it { is_expected.to be nil }
      it { expect(user.reload.login_failure_count).to eq 8 }
    end

    context 'when LDAP mode is enabled' do
      include_context 'setup ldap mock with user mock', for_ssl: true
      include_context 'an ldap connection'
      include_context 'mock searching a user' do
        let(:ldap_user) { double(:ldap_user, to_hash: { 'dn' => 'tux', 'sn' => ['John@obs.de', 'John', 'Smith'] }) }
      end

      let(:user) do
        create(:user, login: 'tux', realname: 'penguin', login_failure_count: 7, last_logged_in_at: 3.hours.ago, email: 'tux@suse.de')
      end

      before do
        stub_const('CONFIG', CONFIG.merge('ldap_mode'        => :on,
                                          'ldap_search_user' => 'tux',
                                          'ldap_search_auth' => 'tux_password'))
      end

      context 'and user is already known by OBS' do
        subject { User.find_with_credentials(user.login, 'tux_password') }

        it { is_expected.to eq user }
        it { expect(subject.login_failure_count).to eq 0 }
        it { expect(subject.last_logged_in_at).to be > 30.seconds.ago }

        it 'updates user data received from the LDAP server' do
          expect(subject.email).to eq 'John@obs.de'
          expect(subject.realname).to eq 'tux'
        end
      end

      context 'and user is not yet known by OBS' do
        subject { User.find_with_credentials('new_user', 'tux_password') }

        it 'creates a new user from the data received by the LDAP server' do
          expect { subject }.to change(User, :count).by 1
          expect(subject.email).to eq 'John@obs.de'
          expect(subject.login).to eq 'new_user'
          expect(subject.realname).to eq 'new_user'
          expect(subject.state).to eq 'confirmed'
          expect(subject.login_failure_count).to eq 0
          expect(subject.last_logged_in_at).to be > 30.seconds.ago
        end
      end
    end
  end

  describe 'autocomplete methods' do
    let!(:foobar) { create(:confirmed_user, login: 'foobar') }
    let!(:fobaz) { create(:confirmed_user, login: 'fobaz') }

    context '#autocomplete_login' do
      it { expect(User.autocomplete_login('foo')).to match_array(['foobar']) }
      it { expect(User.autocomplete_login('bar')).to match_array([]) }
      it { expect(User.autocomplete_login(nil)).to match_array(User.all.pluck(:login)) }
    end

    context '#autocomplete_token' do
      subject { User.autocomplete_token('foo') }

      it { expect(subject).to match_array([name: 'foobar']) }
    end
  end
end
