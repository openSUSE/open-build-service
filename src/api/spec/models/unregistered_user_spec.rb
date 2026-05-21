RSpec.describe UnregisteredUser do
  let(:admin_user) { create(:admin_user, login: 'king') }
  let(:user) { create(:user, login: 'eisendieter') }
  let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
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

  describe '#register' do
    let(:user_attributes) do
      {
        realname: 'Tux Penguin',
        login: 'tux',
        password: 'tux123',
        password_confirmation: 'tux123',
        email: 'tux@northpole.org'
      }
    end

    context 'when registration is allowed' do
      subject! { UnregisteredUser.register(user_attributes) }

      let(:attributes_for_query) { user_attributes.slice(:login, :realname, :email).merge(state: 'confirmed', ignore_auth_services: false) }

      before do
        allow(Configuration).to receive(:registration).and_return('allow')
      end

      it 'creates a new confirmed user' do
        expect(User.where(attributes_for_query)).to exist
      end
    end

    context 'when registration requires confirmation' do
      subject { UnregisteredUser.register(user_attributes) }

      let(:attributes_for_query) { user_attributes.slice(:login, :realname, :email).merge(state: 'unconfirmed', ignore_auth_services: false) }

      before do
        allow(Configuration).to receive(:registration).and_return('confirmation')
      end

      it 'throws an exception that confirms the user registration... and creates an unconfirmed user' do
        expect { subject }.to raise_error(UnregisteredUser::ErrRegisterSave,
                                          'Thank you for signing up! An admin has to confirm your account now. Please be patient.')
        expect(User.where(attributes_for_query)).to exist
      end
    end

    context 'when registration is denied' do
      subject { UnregisteredUser.register(user_attributes) }

      let(:user_count_before) { User.count }

      before do
        allow(Configuration).to receive(:registration).and_return('deny')
      end

      it 'throws an exception' do
        expect { subject }.to raise_error(UnregisteredUser::ErrRegisterSave, 'Sorry, sign up is disabled')
        expect(User.count).to eq(user_count_before)
      end
    end
  end
end
