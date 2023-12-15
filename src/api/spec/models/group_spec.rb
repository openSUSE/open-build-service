RSpec.describe Group do
  let(:group) { create(:group) }
  let(:user) { create(:confirmed_user, login: 'eisendieter') }
  let(:another_user) { create(:confirmed_user, login: 'eisenilse') }

  describe 'validations' do
    it { is_expected.to validate_length_of(:title).is_at_least(2).with_message('must have more than two characters') }
    it { is_expected.to validate_length_of(:title).is_at_most(100).with_message('must have less than 100 characters') }
  end

  describe '#replace_members' do
    subject! { group.replace_members(members) }

    context 'no previous group users' do
      context 'adding one valid user' do
        let(:members) { user.login }

        it 'adds one user successfully' do
          expect(subject).to be_truthy
          expect(group.users).to eq([user])
        end
      end

      context 'adding two valid users' do
        let(:members) { "#{user.login},#{another_user.login}" }

        it 'adds more than one user successfully' do
          expect(subject).to be_truthy
          expect(group.users).to eq([user, another_user])
        end
      end

      context 'with user _nobody_' do
        let(:members) { create(:user_nobody).login }

        it 'does not add the user' do
          expect(subject).to be_falsey
          expect(group.users).to eq([])
          expect(group.errors.full_messages).to eq(["Validation failed: Couldn't find user _nobody_"])
        end
      end
    end

    context 'one previous group user' do
      before do
        group.users << user
      end

      context 'with an invalid user' do
        let(:members) { 'Foobar' }

        it 'errors and does not change users' do
          expect(subject).to be_falsey
          expect(group.users).to eq([user])
          expect(group.errors.full_messages).to eq(["Couldn't find User with login = Foobar"])
        end
      end

      context 'with two users, one of them invalid' do
        let(:members) { "#{another_user.login},Foobar" }

        it 'errors and does not change users' do
          expect(subject).to be_falsey
          expect(group.users).to eq([user])
          expect(group.errors.full_messages).to eq(["Couldn't find User with login = Foobar"])
        end
      end
    end
  end
end
