require 'rails_helper'

RSpec.describe Channel do
  let(:channel) { create(:channel) }

  describe '#disabled?' do
    it { expect(channel).not_to be_disabled }
  end
end
