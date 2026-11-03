RSpec.describe IchainAuthenticatable do
  describe '.for_ichain_username' do
    let(:attributes) { { email: 'hans@sarpei.de', firstname: 'Hans', lastname: 'Sarpei' } }

    context 'when user does not exist' do
      it 'creates a confirmed user' do
        expect { User.for_ichain_username('hans', attributes) }.to change(User, :count).by(1)
        expect(User.find_by(login: 'hans').state).to eq('confirmed')
      end

      it 'stores email and realname' do
        User.for_ichain_username('hans', attributes)
        user = User.find_by(login: 'hans')
        expect(user.email).to eq('hans@sarpei.de')
        expect(user.realname).to eq('Hans Sarpei')
      end

      context 'when registration is denied' do
        before { allow(Configuration).to receive(:registration).and_return('deny') }

        it 'returns nil and creates nothing' do
          expect(User.for_ichain_username('hans', attributes)).to be_nil
          expect(User.find_by(login: 'hans')).to be_nil
        end
      end
    end

    context 'when user exists' do
      let!(:user) { create(:confirmed_user, login: 'hans', email: 'old@example.com', realname: 'Old Name') }

      it 'does not create a user and returns it' do
        expect { expect(User.for_ichain_username('hans', attributes)).to eq(user) }.not_to change(User, :count)
      end

      it 'updates email and realname on each call' do
        User.for_ichain_username('hans', attributes)
        user.reload
        expect(user.email).to eq('hans@sarpei.de')
        expect(user.realname).to eq('Hans Sarpei')
      end

      it 'returns the existing user even when registration is denied' do
        allow(Configuration).to receive(:registration).and_return('deny')
        expect(User.for_ichain_username('hans', attributes)).to eq(user)
      end

      it 'keeps realname and email when the attributes are missing' do
        User.for_ichain_username('hans', {})
        user.reload
        expect(user.email).to eq('old@example.com')
        expect(user.realname).to eq('Old Name')
      end
    end
  end
end
