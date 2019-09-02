require 'rails_helper'

RSpec.describe Webui::UserHelper do
  describe '#user_with_realname_and_icon' do
    skip('Please add some tests')
  end

  describe '#requester_str' do
    let!(:creator) { create(:user, login: 'Adrian') }
    let(:requester) { create(:user, login: 'Ana') }

    it 'do not show the requester if he is the same as the creator' do
      expect(requester_str(creator.login, creator.login, nil)).to be(nil)
    end

    it 'show the requester if he is different as the creator' do
      expect(requester_str(creator.login, requester.login, nil)).to include('user', requester.login)
    end

    it 'show the group' do
      expect(requester_str(creator.login, nil, 'ana-team')).to include('group', 'ana-team')
    end
  end

  describe '#user_image_tag' do
    let(:user) { create(:user, realname: 'Digger', email: 'gordo@example.com') }
    context 'with gravatar configuration disabled' do
      before do
        allow(Configuration).to receive(:gravatar).and_return(false)
      end

      it 'returns default face' do
        expect(user_image_tag(user)).to eq('<img width="20" height="20" alt="Digger" src="/images/default_face.png" />')
      end
    end

    context 'with gravatar configuration enabled' do
      it 'returns gravatar url' do
        expect(user_image_tag(user)).to eq('<img width="20" height="20" alt="Digger" src="https://www.gravatar.com/avatar/66ada5090a2f94d4cfec83801081f3a2?s=20&amp;d=robohash" />')
      end
    end
  end
end
