class Token::APIToken < Token
  # A general API token: a bearer credential that authenticates as the
  # executor across the whole API, replacing the username/password login
  # for programmatic access (CLIs, agents, CI).
  #
  # Unlike the operation tokens (Rebuild/Release/Service/Workflow), the
  # secret is never stored: only its SHA256 hash lives in the `string`
  # column. The plaintext is exposed exactly once, right after creation or
  # regeneration, through #plaintext_token / #display_secret.

  attr_accessor :plaintext_token

  before_validation :mint_token, on: :create

  validate :expires_at_is_in_the_future

  # Returns the token when the presented secret matches a token that is
  # enabled and not expired; otherwise nil. Records the use.
  def self.authenticate(plaintext)
    token = find_by(string: hash_token(plaintext))
    return unless token&.usable?

    token.touch(:last_used_at) # rubocop:disable Rails/SkipsModelValidations
    token
  end

  def self.hash_token(plaintext)
    Digest::SHA256.hexdigest(plaintext.to_s)
  end

  def usable?
    enabled? && (expires_at.nil? || expires_at > Time.zone.now)
  end

  # The secret to show once, right after creation/regeneration. Never the
  # stored hash.
  def display_secret
    plaintext_token
  end

  def regenerate_string
    mint_token
    save
  end

  private

  def mint_token
    self.plaintext_token = "obs_pat_#{SecureRandom.urlsafe_base64(36)}"
    self.string = self.class.hash_token(plaintext_token)
  end

  def expires_at_is_in_the_future
    return if expires_at.nil? || expires_at > Time.zone.now

    errors.add(:expires_at, 'must be in the future')
  end
end
