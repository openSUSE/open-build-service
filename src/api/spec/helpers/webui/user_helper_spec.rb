require 'rails_helper'

RSpec.describe Webui::UserHelper do
  describe '#user_and_role' do
    let(:user) { create(:user) }
    let(:logged_in_user) { create(:user) }
    let(:anonymous_user) { create(:user_nobody) }

    context 'for logged in users' do
      before do
        User.current = logged_in_user
      end

      it 'displays the users realname to a user that is logged in' do
        expect(user_and_role(user.login)).to include(link_to("#{user.realname} (#{user.login})", user_show_path(user: user)))
      end

      it 'falls back to users login if realname is empty' do
        user.update_attributes(realname: '')
        expect(user_and_role(user.login)).to include(link_to(user.login, user_show_path(user: user)))
      end

      it 'does not show an icon if option disables it' do
        expect(user_and_role(user.login, nil, no_icon: true)).to eq(
          link_to("#{user.realname} (#{user.login})", user_show_path(user: user))
        )
      end

      it 'only shows user login if short option is set' do
        expect(user_and_role(user.login, nil, short: true)).to include(link_to(user.login, user_show_path(user: user)))
      end

      it 'appends a role name' do
        expect(user_and_role(user.login, 'test')).to include(
          link_to("#{user.realname} (#{user.login}) as test", user_show_path(user: user))
        )
      end
    end

    context 'for users that are not logged in' do
      before do
        user.email = 'greatguy@nowhere.fi'
        user.save
        User.current = anonymous_user
      end

      it 'does not link to user profiles' do
        expect(user_and_role(user.login)).to eq(
          "<img width=\"20\" height=\"20\" alt=\"#{CGI.escapeHTML(user.realname)}\" " \
          "src=\"http://www.gravatar.com/avatar/803d88429659fa6549ee1a10ccdfbd47?s=20&amp;d=wavatar\" />#{CGI.escapeHTML(user.realname)} (#{user.login})"
        )
      end
    end
  end

  describe '#user_with_realname_and_icon' do
    skip('Please add some tests')
  end

  describe '#requester_str' do
    let!(:creator) { create(:user, login: 'Adrian') }
    let(:requester) { create(:user, login: 'Ana') }

    it 'do not show the requester if he is the same as the creator' do
      expect(requester_str(creator.login, creator.login, nil)).to be nil
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
        expect(user_image_tag(user)).to eq('<img width="20" height="20" alt="Digger" src="http://www.gravatar.com/avatar/66ada5090a2f94d4cfec83801081f3a2?s=20&amp;d=wavatar" />')
      end
    end
  end
end
