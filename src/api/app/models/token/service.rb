class Token::Service < Token
  def valid_signature?(signature, body)
    return false unless signature
    ActiveSupport::SecurityUtils.secure_compare(signature_of(body), signature)
  end

  private

  def signature_of(body)
    'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), string, body)
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id         :integer          not null, primary key
#  string     :string(255)      indexed
#  user_id    :integer          not null, indexed
#  package_id :integer          indexed
#  type       :string(255)
#
# Indexes
#
#  index_tokens_on_string  (string) UNIQUE
#  package_id              (package_id)
#  user_id                 (user_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (user_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
