require 'rails_helper'

RSpec.describe BackendInfo, type: :model do
  describe '.getter' do
    context 'key does not exist' do
      it { expect(BackendInfo.lastnotification_nr).to eq(0) }
    end

    context 'key does exist' do
      before do
        BackendInfo.create(key: :lastnotification_nr, value: 42)
      end

      it { expect(BackendInfo.lastnotification_nr).to eq(42) }
    end
  end

  describe '.setter' do
    subject { BackendInfo.where(key: :lastnotification_nr).first.value.to_i }
    it 'will set the assigned value' do
      BackendInfo.lastnotification_nr = 100
      expect(subject).to eq(100)
    end
  end
end
