# TODO: Please overwrite this comment with something explaining the model target
class Status::Check < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes
  validates :state, :name, presence: true
  # TODO: This should be an ENUM
  VALID_STATES = %w[pending error failure success].freeze
  validates :state, inclusion: {
    in: VALID_STATES,
    message: "State '%{value}' is not a valid. Valid states are: #{VALID_STATES.join(', ')}"
  }

  validates :name, uniqueness: { scope: :status_report }

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :status_report, class_name: 'Status::Report', foreign_key: 'status_reports_id'

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)
  scope :pending, -> { where(state: 'pending') }
  scope :failed, -> { where(state: ['error', 'failure']) }

  #### Validations macros

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def required?
    status_report.checkable.required_checks.include?(name)
  end

  def pending?
    state == 'pending'
  end

  def failed?
    %w[error failure].include?(state)
  end

  #### Alias of methods
end
