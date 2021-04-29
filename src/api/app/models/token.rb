class Token < ApplicationRecord
  belongs_to :user
  belongs_to :package, inverse_of: :tokens

  attr_accessor :package_from_association_or_params, :project_from_association_or_params, :package_name

  has_secure_token :string

  validates :user, presence: true
  validates :string, uniqueness: { case_sensitive: false }

  include Token::Errors

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

  def call(_options)
    raise AbstractMethodCalled
  end

  def package_find_options
    {}
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
