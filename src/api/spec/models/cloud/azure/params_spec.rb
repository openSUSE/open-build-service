require 'rails_helper'

RSpec.describe Cloud::Azure::Params, type: :model, vcr: true do
  describe 'validations' do
    it { is_expected.to validate_presence_of :image_name }
    it { is_expected.to validate_presence_of :subscription }
    it { is_expected.to validate_presence_of :container }
    it { is_expected.to validate_presence_of :storage_account }
    it { is_expected.to validate_presence_of :resource_group }

    it { is_expected.to allow_value('foo.raw.xz').for(:image_name) }
    it { is_expected.not_to allow_value('lorem ipsum').for(:image_name) }

    it { is_expected.to allow_value('container-1').for(:container) }
    it { is_expected.not_to allow_value('container.1').for(:container) }

    it { is_expected.to allow_value('storageaccount1').for(:storage_account) }
    it { is_expected.not_to allow_value('storage_account1').for(:storage_account) }

    it { is_expected.to allow_value('-my-resource_group').for(:resource_group) }
    it { is_expected.to allow_value('my-resource_group-').for(:resource_group) }
    it { is_expected.not_to allow_value('-my-resource_group.').for(:resource_group) }
  end

  describe '.build' do
    it 'ignores not necessary values' do
      expect(Cloud::Azure::Params.build(not: :necessary, image_name: 'myImage').image_name).to eq('myImage')
    end
  end
end
