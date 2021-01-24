require 'rails_helper'

RSpec.describe SavedReply do
  describe 'validations' do
    before :each do
      @saved_reply = FactoryBot.build(:saved_reply)
      assert @saved_reply.valid?
    end

    it 'should have title' do
      @saved_reply.title = nil
      expect(@saved_reply.valid?).to be_falsey
    end

    it 'should have body' do
      @saved_reply.body = nil
      expect(@saved_reply.valid?).to be_falsey
    end
  end

  describe 'relationship with users' do
    let(:user) { create(:admin_user, login: 'king') }
    let(:saved_reply) { create(:saved_reply, user: user) }

    it { expect(user.saved_replies).to include(saved_reply) }
  end
end
