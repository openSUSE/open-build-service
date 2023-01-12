class Token < ApplicationRecord
  belongs_to :executor, class_name: 'User'
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

  # TODO: move to Token::Workflow model
  scope :owned_tokens, ->(user) { where(executor: user).where.not(type: ['Token::Rss']) }
  scope :shared_tokens, ->(user) { user.shared_workflow_tokens }
  scope :group_shared_tokens, ->(user) { user.groups.map(&:shared_workflow_tokens).flatten } # TODO: transform to ActiveRecord_Relation

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

  def owned_by?(some_user)
    executor == some_user
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id                          :integer          not null, primary key
#  description                 :string(64)       default("")
#  scm_token                   :string(255)      indexed
#  string                      :string(255)      indexed
#  triggered_at                :datetime
#  type                        :string(255)
#  workflow_configuration_path :string(255)      default(".obs/workflows.yml")
#  workflow_configuration_url  :string(255)
#  executor_id                 :integer          not null, indexed
#  package_id                  :integer          indexed
#
# Indexes
#
#  index_tokens_on_scm_token  (scm_token)
#  index_tokens_on_string     (string) UNIQUE
#  package_id                 (package_id)
#  user_id                    (executor_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (executor_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
