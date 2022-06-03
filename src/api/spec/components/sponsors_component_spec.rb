require 'rails_helper'

RSpec.describe SponsorsComponent, type: :component do
  context 'with sponsors' do
    let(:sponsor) do
      {
        'icon' => 'sponsor_suse',
        'url' => '/foo',
        'description' => 'Sponsor foo',
        'name' => 'foo'
      }
    end
    let(:config) { { 'sponsors' => [sponsor] } }

    before do
      render_inline(described_class.new(config: config))
    end

    it do
      expect(rendered_content).to have_text('Open Build Service is sponsored by')
    end

    it do
      expect(rendered_content).to have_css('.sponsor-item')
    end
  end

  context 'without sponsors' do
    let(:config) { {} }

    before do
      render_inline(described_class.new(config: config))
    end

    it do
      expect(rendered_content).not_to have_text('Open Build Service is sponsored by')
    end

    it do
      expect(rendered_content).not_to have_css('.sponsor-item')
    end
  end
end
