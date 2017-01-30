require 'rails_helper'

RSpec.describe 'Image templates' do
  context 'feature switch' do
    it 'enabled' do
      Feature.run_with_activated(:image_templates) do
        # We need to forced reload routes because conditional routes definition based on the feature switch
        Rails.application.reloader.reload!
        expect(get: :image_templates).to be_routable
      end
    end

    it 'disabled' do
      Feature.run_with_deactivated(:image_templates) do
        # We need to forced reload routes because conditional routes definition based on the feature switch
        Rails.application.reloader.reload!
        expect(get: :image_templates).not_to be_routable
      end
    end
  end
end
