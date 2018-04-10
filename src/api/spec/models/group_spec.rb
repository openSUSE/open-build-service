# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Group do
  let(:group) { create(:group) }
  let(:user) { create(:confirmed_user, login: 'eisendieter') }
  let(:another_user) { create(:confirmed_user, login: 'eisenilse') }

  describe 'validations' do
    it { is_expected.to validate_length_of(:title).is_at_least(2).with_message('must have more than two characters') }
    it { is_expected.to validate_length_of(:title).is_at_most(100).with_message('must have less than 100 characters') }
  end

  context '#replace_members' do
    context 'with valid user input' do
      it 'adds one user successfully' do
        group.replace_members([user.login])
        expect(group.users).to eq([user])
      end

      it 'adds more than one user successfully' do
        group.replace_members([user.login, another_user.login])
        expect(group.users).to eq([user])
      end
    end

    context 'with invalid user input' do
      before(:each) do
        group.users << user
        @before = group.users
      end

      it 'does not change users' do
        group.replace_members('Foobar')
        expect(group.users).to eq(@before)
        expect(group.errors.full_messages).to eq(["Couldn't find User with login = Foobar"])
      end

      it 'does not change users when one user is valid' do
        group.replace_members("#{user.login},Foobar")
        expect(group.users).to eq(@before)
        expect(group.errors.full_messages).to eq(["Couldn't find User with login = Foobar"])
      end
    end
  end
end
