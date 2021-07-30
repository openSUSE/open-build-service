class Token < ApplicationRecord
  belongs_to :user
  has_many :event_subscriptions, dependent: :destroy
  belongs_to :package, inverse_of: :tokens

  attr_accessor :object_to_authorize

  has_secure_token :string

  validates :user, presence: true
  validates :string, uniqueness: { case_sensitive: false }
  validates :scm_token, absence: true, if: -> { type != 'Token::Workflow' }

  include Token::Errors

  OPERATIONS = ['Rebuild', 'Release', 'Service', 'Workflow'].freeze

  def token_name
    self.class.token_name
  end

  def self.token_type(action)
    case action
    when 'rebuild'
      Token::Rebuild
    when 'release'
      Token::Release
    when 'workflow'
      Token::Workflow
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

  def follow_links?
    package_find_options[:follow_multibuild] || package_find_options[:follow_project_links]
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id         :integer          not null, primary key
#  scm_token  :string(255)      indexed
#  string     :string(255)      indexed
#  type       :string(255)
#  package_id :integer          indexed
#  user_id    :integer          not null, indexed
#
# Indexes
#
#  index_tokens_on_scm_token  (scm_token)
#  index_tokens_on_string     (string) UNIQUE
#  package_id                 (package_id)
#  user_id                    (user_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (user_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
