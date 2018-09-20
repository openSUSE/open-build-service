require 'rails_helper'

RSpec.describe Architecture do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name) }

  describe '#worker' do
    let(:i586) { Architecture.find_by(name: 'i586') }

    it { expect(i586.worker).to eq('x86_64') }
  end
end
