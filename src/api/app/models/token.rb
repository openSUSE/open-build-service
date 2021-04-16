class Token < ApplicationRecord
  belongs_to :user
  belongs_to :package, inverse_of: :tokens

  has_secure_token :string

  validates :user, presence: true

  def token_name
    self.class.token_name
  end

  def self.token_type(action)
    case action
    when 'rebuild'
      Token::Rebuild
    when 'release'
      Token::Release
    else
      # default is Token::Service
      Token::Service
    end
  end

  # TODO
  # make sure:
  # a) the name makes sense
  # b) it lives in the right place
  def package_find_options
    { use_source: true,
      follow_project_links: false,
      follow_multibuild: false }
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id         :integer          not null, primary key
#  string     :string(255)      indexed
#  type       :string(255)
#  package_id :integer          indexed
#  user_id    :integer          not null, indexed
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
