require 'rails_helper'

RSpec.describe User do
  let(:admin_user) { create(:admin_user, login: 'king') }
  let(:user) { create(:user, login: 'eisendieter') }
  let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
  let(:input) { { 'Event::RequestCreate' => { source_maintainer: '1' } } }
  let(:project_with_package) { create(:project_with_package, name: 'project_b') }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:login).with_message('must be given') }
    it { is_expected.to validate_length_of(:login).is_at_least(2).with_message('must have more than two characters.') }
    it { is_expected.to validate_length_of(:login).is_at_most(100).with_message('must have less than 100 characters.') }

    it { is_expected.to allow_value('king@opensuse.org').for(:email) }
    it { is_expected.to_not allow_values('king.opensuse.org', 'opensuse.org', 'opensuse').for(:email) }

    it { is_expected.to validate_presence_of(:password).with_message('must be given') }
    it { is_expected.to validate_length_of(:password).is_at_least(6).with_message('must have between 6 and 64 characters.') }
    it { is_expected.to validate_length_of(:password).is_at_most(64).with_message('must have between 6 and 64 characters.') }

    it { is_expected.to validate_presence_of(:password_hash_type).with_message('must be given') }
    it { expect(user.password_hash_type).to eq('md5') }

    it 'validates that password_hash_type is in User::PASSWORD_HASH_TYPES' do
      user.password_hash_type = SecureRandom.hex
      expect(user.valid?).to be false
      expect(user.errors.full_messages).to include("Password hash type #{user.password_hash_type} must be in the list of hash types.")
      User::PASSWORD_HASH_TYPES.each do |hash_type|
        user.password_hash_type = hash_type
        expect(user.errors.full_messages).not_to include("Password hash type #{hash_type} must be in the list of hash types.")
      end
    end

    it 'validates that password changes with password_hash_type' do
      user.password_hash_type = 'md5crypt'
      expect(user.valid?).to be false
      expect(user.errors.full_messages.to_sentence).to eq('Password hash type cannot be changed unless a new password has been provided.')
      user.password = "changedit"
      expect(user.valid?).to be true
    end

    it { expect(user.state).to eq('unconfirmed') }

    it { expect(create(:user)).to validate_uniqueness_of(:login).with_message('is the name of an already existing user.') }
  end

  describe 'password validation' do
    shared_examples 'tests for password related methods for encryption with' do |hash_type|
      let(:user) { create(:user, password_hash_type: hash_type) }
      let(:password) { SecureRandom.hex }

      describe '#password_equals?' do
        it { expect(user.password_equals?('buildservice')).to be true }
        it { expect(user.password_equals?(password)).to be false }
      end

      describe '#update_password' do
        before do
          user.update_password(password)
        end

        it 'updates the password' do
          expect(user.password_equals?(password)).to be true
        end
      end

      describe '#password_hash_type=' do
        let(:new_hash_type) { hash_type == 'md5' ? 'sha256' : 'md5' }

        it 'changes the password hash type' do
          user.password_hash_type = new_hash_type
          expect(user.password_hash_type).to eq(new_hash_type)
        end
      end
    end

    User::PASSWORD_HASH_TYPES.each do |hash_type|
      context "hash type '#{hash_type}'" do
        include_examples 'tests for password related methods for encryption with', hash_type
      end
    end
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

    it "will have involved packages" do
      create(:relationship_package_user, package: project_with_package.packages.first, user: user)
      expect(user.involved_packages).to include(project_with_package.packages.first)
    end

    it "will have involved projects" do
      create(:relationship_project_user, project: project, user: user)
      create(:relationship_project_user, project: project_with_package, user: user)
      involved_projects = user.involved_projects
      expect(involved_projects).to include(user.home_project)
      expect(involved_projects).to include(project)
      expect(involved_projects).to include(project_with_package)
    end

    it "will have owned projects and packages" do
      create(:attrib, attrib_type: AttribType.find_by(name: 'OwnerRootProject'), project: project_with_package)
      create(:relationship_package_user, package: project_with_package.packages.first, user: user)
      create(:relationship_project_user, project: project_with_package, user: user)
      owned_packages = user.owned_packages
      expect(owned_packages[0]).to eq([nil, project_with_package.name])
      expect(owned_packages[1]).to eq([project_with_package.packages.first.name, project_with_package.name])
    end
  end

  describe 'requests' do
    let(:creator) { create(:confirmed_user, login: 'tom') }
    let(:receiver) { create(:confirmed_user, login: 'king') }
    let(:reviewer) { create(:confirmed_user, login: 'alan') }

    let(:source_project) { creator.home_project }
    let(:source_package) { create(:package, project: source_project) }
    let(:target_project) { receiver.home_project }
    let(:target_package) { create(:package, project: target_project) }

    let(:incoming_review) do
      create(:review_bs_request,
             creator: creator.login,
             target_project: target_project.name,
             target_package: target_package.name,
             source_project: source_project.name,
             source_package: source_package.name,
             reviewer: reviewer.login)
    end
    let(:request) do
      create(:bs_request_with_submit_action,
             creator: creator.login,
             target_project: target_project.name,
             target_package: target_package.name,
             source_project: source_project.name,
             source_package: source_package.name)
    end
    let(:declined_request) do
      create(:declined_bs_request,
             creator: creator.login,
             target_project: target_project.name,
             target_package: target_package.name,
             source_project: source_project.name,
             source_package: source_package.name)
    end

    it 'returns incoming reviews' do
      reviews = [incoming_review]
      expect(reviewer.involved_reviews).to match_array(reviews)
    end

    it 'returns incoming reviews with search' do
      expect(reviewer.involved_reviews('random_string')).to be_empty
    end

    it 'returns incoming requests' do
      requests = [request]
      expect(receiver.incoming_requests).to match_array(requests)
    end

    it 'returns incoming requests with search' do
      expect(receiver.incoming_requests('random_string')).to be_empty
    end

    it 'returns outgoing requests' do
      requests = [request]
      expect(creator.outgoing_requests).to match_array(requests)
    end

    it 'returns outgoing requests with search' do
      expect(creator.outgoing_requests('random_string')).to be_empty
    end

    it 'returns declined requests' do
      requests = [declined_request]
      expect(creator.declined_requests).to match_array(requests)
    end

    it 'returns declined requests with search' do
      expect(creator.declined_requests('random_string')).to be_empty
    end
  end

  describe 'create_user_with_fake_pw!' do
    context 'with login and email' do
      let(:user) { User.create_user_with_fake_pw!({ login: 'tux', email: 'some@email.com' }) }

      it 'creates a user with a fake password' do
        expect(user.password).not_to eq(User.create_user_with_fake_pw!({ login: 'tux2', email: 'some@email.com' }).password)
      end

      it 'creates a user from given attributes' do
        expect(user).to be_an(User)
        expect(user.login).to eq('tux')
        expect(user.email).to eq('some@email.com')
      end
    end

    context 'without params' do
      it 'throws an exception' do
        expect{ User.create_user_with_fake_pw! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#declined_requests' do
    let(:target_package) { create(:package) }
    let(:source_package) { create(:package) }
    let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
    let!(:new_bs_request) { create(:bs_request, creator: confirmed_user) }
    let!(:declined_bs_request) {
      create(:declined_bs_request,
             target_project: target_package.project,
             target_package: target_package,
             source_project: source_package.project,
             source_package: source_package,
             creator: confirmed_user)
    }
    let!(:admin_bs_request) {
      create(:declined_bs_request,
             target_project: target_package.project,
             target_package: target_package,
             source_project: source_package.project,
             source_package: source_package,
             creator: admin_user)
    }

    subject { confirmed_user.declined_requests }

    it 'does include requests created by the user and in state :declined' do
      expect(subject).to include(declined_bs_request)
    end

    it 'does include requests with matching search parameter' do
      expect(confirmed_user.declined_requests('confirmed_user')).to include(declined_bs_request)
    end

    it 'does not include requests with not matching search parameter' do
      expect(confirmed_user.declined_requests('not-existent')).not_to include(declined_bs_request)
    end

    it 'does not include requests created by any other user' do
      expect(subject).not_to include(admin_bs_request)
    end

    it 'does not include requests in any other state except :declined' do
      expect(subject).not_to include(new_bs_request)
    end
  end

  describe '#outgoing_requests' do
    let(:target_package) { create(:package) }
    let(:source_package) { create(:package) }
    let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
    let!(:new_bs_request) { create(:bs_request, creator: confirmed_user) }
    let!(:review_bs_request) {
      create(:review_bs_request,
             target_project: target_package.project,
             target_package: target_package,
             source_project: source_package.project,
             source_package: source_package,
             creator: confirmed_user,
             reviewer: admin_user)
    }
    let!(:declined_bs_request) {
      create(:declined_bs_request,
             target_project: target_package.project,
             target_package: target_package,
             source_project: source_package.project,
             source_package: source_package,
             creator: confirmed_user)
    }
    let!(:admin_bs_request) {
      create(:bs_request,
             target_project: target_package.project,
             target_package: target_package,
             source_project: source_package.project,
             source_package: source_package,
             creator: admin_user)
    }

    subject { confirmed_user.outgoing_requests }

    it 'does include requests created by the user and in state :new' do
      expect(subject).to include(new_bs_request)
    end

    it 'does include requests created by the user and in state :review' do
      expect(subject).to include(review_bs_request)
    end

    it 'does include requests with matching search parameter' do
      expect(confirmed_user.outgoing_requests('confirmed_user')).to include(new_bs_request)
    end

    it 'does not include requests with not matching search parameter' do
      expect(confirmed_user.outgoing_requests('not-existent')).not_to include(new_bs_request)
    end

    it 'does not include requests created by any other user' do
      expect(subject).not_to include(admin_bs_request)
    end

    it 'does not include requests in any other state except :new or :review' do
      expect(subject).not_to include(declined_bs_request)
    end
  end

  describe '#incoming_requests' do
    let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }

    shared_examples 'incoming_requests' do
      let(:source_package) { create(:package) }

      let!(:maintained_request) {
        create(:bs_request_with_submit_action,
               target_project: target_package.project,
               target_package: target_package,
               source_project: source_package.project,
               source_package: source_package,
               creator: admin_user.login
              )
      }

      let!(:not_maintained_request) {
        create(:bs_request_with_submit_action,
               target_project: not_maintained_target_package.project,
               target_package: not_maintained_target_package,
               source_project: source_package.project,
               source_package: source_package,
               creator: admin_user.login
              )
      }

      subject { confirmed_user.incoming_requests }

      it 'does include requests of maintained subject' do
        expect(subject).to include(maintained_request)
      end

      it 'does not include requests of not maintained subject' do
        expect(subject).not_to include(not_maintained_request)
      end

      it 'does not include requests in any other state expect new' do
        maintained_request.state = :review
        maintained_request.save
        expect(subject).not_to include(maintained_request)
      end

      it 'does include requests if search does match' do
        expect(confirmed_user.incoming_requests(admin_user.login)).to include(maintained_request)
      end

      it 'does nots include requests if search does not match' do
        expect(confirmed_user.incoming_requests('does not exist')).not_to include(maintained_request)
      end
    end

    context 'with maintained project' do
      it_behaves_like 'incoming_requests' do
        let(:target_package) { create(:package) }
        let!(:relationship_project_user) { create(:relationship_project_user, user: confirmed_user, project: target_package.project) }

        let(:not_maintained_target_package) { create(:package) }
        let!(:relationship_project_admin) { create(:relationship_project_user, user: admin_user, project: target_package.project) }
      end
    end

    context 'with maintained package' do
      it_behaves_like 'incoming_requests' do
        let(:target_package) { create(:package) }
        let!(:relationship_package_user) { create(:relationship_package_user, user: confirmed_user, package: target_package) }

        let(:not_maintained_target_package) { create(:package) }
        let!(:relationship_package_admin) { create(:relationship_package_user, user: admin_user, package: target_package) }
      end
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

      it 'returns a BsRequest::ActiveRecord_Relation' do
        expect(subject.class).to eq(BsRequest::ActiveRecord_Relation)
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
        let!(:review_with_same_creator_and_reviewer) {
          create(:review, by_user: confirmed_user.login, bs_request: request_with_same_creator_and_reviewer)
        }

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
        let!(:review_with_same_creator_and_reviewer) {
          create(:review, by_project: package.project.name, by_package: package.name, bs_request: request_with_same_creator_and_reviewer)
        }

        let(:other_package) { create(:package) }
        let(:request_of_another_subject) { create(:bs_request, creator: admin_user.login) }
        let!(:review_of_another_subject) {
          create(:review, by_project: other_package.project.name, by_package: other_package.name, bs_request: request_of_another_subject)
        }
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
end
