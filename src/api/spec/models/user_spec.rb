require 'rails_helper'

RSpec.describe User do
  let(:admin_user) { create(:admin_user, login: 'king') }
  let(:user) { create(:user, login: 'eisendieter') }
  let(:input) { { 'Event::RequestCreate' => { source_maintainer: '1' } } }

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

    it { expect(user.password_hash_type).to eq('md5') }

    it { expect(user.state).to eq(User::STATES['unconfirmed']) }

    it 'validates uniqueness of login' do
      invalid_user = build(:user, login: user.login)
      invalid_user.save
      expect(invalid_user.errors.full_messages).to eq(['Login is the name of an already existing user.'])
    end
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

  it 'creates a home project by default if allow_user_to_create_home_project is enabled' do
    Configuration.stubs(:allow_user_to_create_home_project).returns(true)
    user = create(:confirmed_user)
    project = Project.find_by(name: user.home_project_name)
    expect(project).not_to be_nil
  end

  it "doesn't creates a home project if allow_user_to_create_home_project is disabled" do
    Configuration.stubs(:allow_user_to_create_home_project).returns(false)
    user = create(:confirmed_user)
    project = Project.find_by(name: user.home_project_name)
    expect(project).to be_nil
  end
end
