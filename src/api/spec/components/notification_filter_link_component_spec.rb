require 'rails_helper'

RSpec.describe NotificationFilterLinkComponent, type: :component do
  context 'the filter item matches the selected filter and the amount is greater than 0' do
    let(:link_selector) { 'a.active[href="/my/notifications?type=comments"]' }

    before do
      render_inline(described_class.new(text: 'Comments', filter_item: { type: 'comments' },
                                        selected_filter: { type: 'comments' }, amount: 20))
    end

    it 'displays a link with the active class and containing a badge of the light color' do
      expect(rendered_content).to have_css(link_selector, text: 'Comments')

      expect(rendered_content).to have_css("#{link_selector} span.badge.bg-light", text: 20)
    end
  end

  context 'the filter item matches the selected filter and the amount is not greater than 0' do
    let(:link_selector) { 'a.active[href="/my/notifications?project=home%3AAdmin"]' }

    before do
      render_inline(described_class.new(text: 'home:Admin', filter_item: { project: 'home:Admin' },
                                        selected_filter: { project: 'home:Admin' }, amount: 0))
    end

    it 'displays a link with the active class, but without a badge' do
      expect(rendered_content).to have_css(link_selector, text: 'home:Admin')

      expect(rendered_content).not_to have_css("#{link_selector} span.badge")
    end
  end

  context 'the filter item does not match the selected filter and the amount is greater than 0' do
    let(:link_selector) { 'a[href="/my/notifications?group=iron_maiden"]' }

    before do
      render_inline(described_class.new(text: 'iron_maiden', filter_item: { group: 'iron_maiden' },
                                        selected_filter: { type: 'requests' }, amount: 10))
    end

    it 'displays a link without the active class, but containing a badge of the primary color' do
      expect(rendered_content).to have_css(link_selector, text: 'iron_maiden')

      expect(rendered_content).to have_css("#{link_selector} span.badge.bg-primary", text: 10)
    end
  end

  context 'the filter item does not match the selected filter and the amount is not greater than 0' do
    let(:link_selector) { 'a[href="/my/notifications?group=iron_maiden"]' }

    before do
      render_inline(described_class.new(text: 'iron_maiden', filter_item: { group: 'iron_maiden' },
                                        selected_filter: { type: 'requests' }, amount: 0))
    end

    it 'displays a link without the active class and a badge' do
      expect(rendered_content).to have_css(link_selector, text: 'iron_maiden')

      expect(rendered_content).not_to have_css("#{link_selector} span.badge")
    end
  end
end
