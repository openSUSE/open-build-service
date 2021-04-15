require 'rails_helper'

RSpec.describe Token, type: :model do
  describe 'validations' do
    let(:release_token) { create(:release_token) }

    it { expect(release_token).to validate_uniqueness_of(:string).case_insensitive }
    it { is_expected.to have_secure_token(:string) }
    it { is_expected.to validate_presence_of(:user) }
  end

  describe '.token_type' do
    it { expect(described_class.token_type('release')).to eq(Token::Release) }
    it { expect(described_class.token_type('rebuild')).to eq(Token::Rebuild) }
    it { expect(described_class.token_type('everythingelse')).to eq(Token::Service) }
  end

  describe '#call' do
    it 'raises an exception' do
      expect { described_class.new.call({}) }.to raise_error(AbstractMethodCalled, 'AbstractMethodCalled')
    end
  end
end
