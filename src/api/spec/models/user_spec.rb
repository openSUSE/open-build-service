require 'rails_helper'

RSpec.describe User do
  let(:admin_user) { create(:admin_user, login: 'king') }
  let(:user) { create(:user, login: 'eisendieter') }
  let(:input) { { 'Event::RequestCreate' => { source_maintainer: '1' } } }
  let(:project_with_package) { create(:project_with_package, name: 'project_b') }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:login).with_message('must be given') }
    it { is_expected.to validate_length_of(:login).is_at_least(2).with_message('must have more than two characters.') }
    it { is_expected.to validate_length_of(:login).is_at_most(100).with_message('must have less than 100 characters.') }

    it { is_expected.to validate_presence_of(:email).with_message('must be given') }
    it { is_expected.to allow_value('king@opensuse.org').for(:email) }
    it { is_expected.to_not allow_values('king.opensuse.org', 'opensuse.org', 'opensuse').for(:email) }

    it { is_expected.to validate_presence_of(:password).with_message('must be given') }
    it { is_expected.to validate_length_of(:password).is_at_least(6).with_message('must have between 6 and 64 characters.') }
    it { is_expected.to validate_length_of(:password).is_at_most(64).with_message('must have between 6 and 64 characters.') }

    it { is_expected.to validate_presence_of(:password_hash_type).with_message('must be given') }
    it { is_expected.to validate_inclusion_of(:password_hash_type).in_array(User::PASSWORD_HASH_TYPES) }
    it { expect(user.password_hash_type).to eq('md5') }

    it { expect(user.state).to eq('unconfirmed') }

    it { expect(create(:user)).to validate_uniqueness_of(:login).with_message('is the name of an already existing user.') }
  end

  shared_examples 'updates notifications' do
    before do
      # If the parameter is the User class, the user_id has to be nil
      @id = object.instance_of?(User) ? object.id : nil
    end

    context 'when valid'do
      it 'updates one global notification' do
        object.update_notifications(input)
        expect(
          EventSubscription.exists?(user_id: @id, eventtype: 'Event::RequestCreate', receiver_role: 'source_maintainer', receive: true)
        ).to be true
      end

      it 'does not update User notification when Event disabled' do
        object.update_notifications({ })
        expect(
          EventSubscription.exists?(user_id: @id, eventtype: 'Event::RequestCreate', receiver_role: 'source_maintainer', receive: false)
        ).to be true
      end

      context 'for more than one User notification' do
        before do
          input['Event::CommentForPackage'] = { commenter: '1' }
          object.update_notifications(input)
        end

        it 'creates an EventSubscription for the maintainer' do
          expect(
            EventSubscription.exists?(user_id: @id, eventtype: 'Event::RequestCreate', receiver_role: 'source_maintainer', receive: true)
          ).to be true
        end

        it 'creates an EventSubscription for a commenter' do
          expect(
            EventSubscription.exists?(user_id: @id, eventtype: 'Event::CommentForPackage', receiver_role: 'commenter', receive: true)
          ).to be true
        end
      end
    end

    context 'when invalid'do
      it 'does not update User notification' do
        object.update_notifications({ 'Event::InvalidEvent' => { source_maintainer: '1' } })
        expect(
          EventSubscription.exists?(user_id: @id, eventtype: 'Event::RequestCreate', receiver_role: 'source_maintainer', receive: true)
        ).to be false
      end
    end
  end

  context '.update_notifications' do
    it_behaves_like 'updates notifications' do
      let(:object) { User }
    end
  end

  context '#update_notifications' do
    it_behaves_like 'updates notifications' do
      let(:object) { admin_user }
    end
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
    end

    ['md5', 'md5crypt', 'sha256crypt'].each do |hash_type|
      context "hash type '#{hash_type}'" do
        include_examples 'tests for password related methods for encryption with', hash_type
      end
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
end
