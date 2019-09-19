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
end
