RSpec.describe Token::APIToken do
  let(:user) { create(:confirmed_user) }
  let(:token) { create(:api_token, executor: user) }

  describe 'on creation' do
    it 'stores only the hash of the secret, never the plaintext' do
      expect(token.string).to eq(Digest::SHA256.hexdigest(token.plaintext_token))
      expect(token.string).not_to include(token.plaintext_token)
    end

    it 'exposes the plaintext secret exactly once via display_secret' do
      expect(token.display_secret).to eq(token.plaintext_token)
    end

    it 'rejects an expiry in the past' do
      expect(build(:api_token, executor: user, expires_at: 1.hour.ago)).not_to be_valid
    end

    it 'accepts an expiry in the future' do
      expect(build(:api_token, executor: user, expires_at: 1.hour.from_now)).to be_valid
    end
  end

  describe '.authenticate' do
    it 'returns the token for the correct secret' do
      expect(described_class.authenticate(token.plaintext_token)).to eq(token)
    end

    it 'records the use in last_used_at' do
      expect { described_class.authenticate(token.plaintext_token) }.to change { token.reload.last_used_at }.from(nil)
    end

    it 'returns nil for a wrong secret' do
      expect(described_class.authenticate('bogus')).to be_nil
    end

    context 'with an expired token' do
      before { token.update_column(:expires_at, 1.hour.ago) } # rubocop:disable Rails/SkipsModelValidations

      it 'returns nil' do
        expect(described_class.authenticate(token.plaintext_token)).to be_nil
      end
    end

    context 'with a disabled token' do
      before { token.update!(enabled: false) }

      it 'returns nil' do
        expect(described_class.authenticate(token.plaintext_token)).to be_nil
      end
    end
  end

  describe '#regenerate_string' do
    it 'mints a new secret' do
      old_secret = token.plaintext_token

      expect(token.regenerate_string).to be_truthy
      expect(token.display_secret).not_to eq(old_secret)
    end

    it 'invalidates the old secret' do
      old_secret = token.plaintext_token
      token.regenerate_string

      expect(described_class.authenticate(old_secret)).to be_nil
      expect(described_class.authenticate(token.plaintext_token)).to eq(token)
    end
  end
end
