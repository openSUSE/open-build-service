require 'rails_helper'

RSpec.describe AvatarAndLinkComponent, type: :component do
  let(:user) { create(:user, login: 'King') }
  let(:group) { create(:group) }

  context 'for user' do
    context 'with short text link' do
      before do
        render_inline(described_class.new(avatar_object: user))
      end

      it 'displays user avatar' do
        expect(rendered_content).to have_selector("img[title='#{user.name}']", count: 1)
      end

      it 'displays a link with a short text' do
        expect(rendered_content).to have_selector('a', text: "#{user.login}", count: 1)
      end
    end

    context 'with long link text' do
      before do
        render_inline(described_class.new(avatar_object: user, long_link_text: true))
      end

      it 'displays user avatar' do
        expect(rendered_content).to have_selector("img[title='#{user.name}']", count: 1)
      end

      it 'displays a link with a long text' do
        expect(rendered_content).to have_selector('a', text: "#{user.realname} (#{user.login})", count: 1)
      end
    end
  end

  context 'for group' do
    before do
      render_inline(described_class.new(avatar_object: group, shape: :circle))
    end

    it 'displays avatar with group name in the title' do
      expect(rendered_content).to have_selector("img[title='#{group.name}']", count: 1)
    end

    it 'displays a link with a text' do
      expect(rendered_content).to have_selector('a', text: group.title, count: 1)
    end
  end
end
