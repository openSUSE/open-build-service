require 'rails_helper'

RSpec.describe AvatarComponent, type: :component do
  let(:user) { create(:user, login: 'King') }
  let(:group) { create(:group) }

  context 'for user' do
    before do
      render_inline(described_class.new(name: user.name, email: user.email))
    end

    it 'displays avatar with user name in the title' do
      expect(rendered_content).to have_selector("img[title='#{user.name}']", count: 1)
    end

    it 'displays avatar without circle' do
      expect(rendered_content).not_to have_selector('img.rounded-circle', count: 1)
    end
  end

  context 'for group' do
    before do
      render_inline(described_class.new(name: group.name, email: group.email, shape: :circle))
    end

    it 'displays avatar with group name in the title' do
      expect(rendered_content).to have_selector("img[title='#{group.name}']", count: 1)
    end

    it 'displays avatar inside a circle' do
      expect(rendered_content).to have_selector('img.rounded-circle', count: 1)
    end
  end
end
