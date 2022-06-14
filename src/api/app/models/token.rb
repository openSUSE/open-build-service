class Token < ApplicationRecord
  belongs_to :user
  has_many :event_subscriptions, dependent: :destroy
  belongs_to :package, inverse_of: :tokens, optional: true

  attr_accessor :object_to_authorize

  has_secure_token :string

  before_validation do
    self.description ||= ''
  end

  validates :description, length: { maximum: 64 }
  validates :string, uniqueness: { case_sensitive: false }
  validates :scm_token, absence: true, if: -> { type != 'Token::Workflow' }

  include Token::Errors

  scope :owned_tokens, ->(user) { where(user: user).where.not(type: ['Token::Rss']).includes(package: :project) }
  scope :shared_tokens, ->(user) { user.shared_workflow_tokens.includes(package: :project) }

  OPERATIONS = ['Rebuild', 'Release', 'Service', 'Workflow'].freeze

  def token_name
    self.class.token_name.downcase
  end

  def self.token_name
    name.demodulize
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

  def set_triggered_at
    update(triggered_at: Time.zone.now)
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id           :integer          not null, primary key
#  description  :string(64)       default("")
#  scm_token    :string(255)      indexed
#  string       :string(255)      indexed
#  triggered_at :datetime
#  type         :string(255)
#  package_id   :integer          indexed
#  user_id      :integer          not null, indexed
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
