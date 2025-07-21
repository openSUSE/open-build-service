RSpec.describe Token do
  describe 'validations' do
    let(:release_token) { create(:release_token) }

    it { expect(release_token).to validate_uniqueness_of(:string).case_insensitive }
    it { is_expected.to have_secure_token(:string) }
    it { is_expected.to belong_to(:executor) }
  end

  describe '.token_type' do
    it { expect(described_class.token_type('release')).to eq(Token::Release) }
    it { expect(described_class.token_type('rebuild')).to eq(Token::Rebuild) }
    it { expect { described_class.token_type('everythingelse') }.to raise_error(Token::Errors::UnknownOperation, "unknown token operation 'everythingelse'") }
  end

  describe '#call' do
    it 'raises an exception' do
      expect { described_class.new.call({}) }.to raise_error(AbstractMethodCalled, 'AbstractMethodCalled')
    end
  end
end
