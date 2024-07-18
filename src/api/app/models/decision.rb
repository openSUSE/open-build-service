class Decision < ApplicationRecord
  TYPES = %w[DecisionFavored DecisionCleared DecisionFavoredWithCommentModeration DecisionFavoredWithUserDeletion DecisionFavoredWithDeleteRequest DecisionFavoredWithUserCommentingRestriction].freeze

  validates :reason, presence: true, length: { maximum: 65_535 }
  validates :type, presence: true, length: { maximum: 255 }

  belongs_to :moderator, class_name: 'User', optional: false

  has_many :reports, dependent: :nullify

  after_create :track_decision

  def description
    'The moderator decided on the report'
  end

  # List of all viable types for a reportable, used in the decision creation form
  def self.types(reportable)
    TYPES.filter_map do |decision_type_name|
      decision_type = decision_type_name.constantize
      [decision_type.display_name, decision_type.name] if decision_type.display?(reportable)
    end.compact.to_h
  end

  # We use this to determine if the decision type should be displayed for reportable
  def self.display?(_reportable)
    true
  end

  # We display this in the decision creation form
  def self.display_name
    'unknown'
  end

  private

  def create_event
    raise AbstractMethodCalled
  end

  def event_parameters
    { id: id, moderator_id: moderator.id, reason: reason, report_last_id: reports.last.id, reportable_type: reports.first.reportable.class.name }
  end

  def track_decision
    RabbitmqBus.send_to_bus('metrics', "decision,type=#{type} hours_before_decision=#{hours_before_decision},count=1")
  end

  def hours_before_decision
    first_report_created_at = reports.order(created_at: :asc).first.created_at

    ((created_at - first_report_created_at) / 1.hour).floor
  end
end

# == Schema Information
#
# Table name: decisions
#
#  id           :bigint           not null, primary key
#  reason       :text(65535)      not null
#  type         :string(255)      default("DecisionCleared"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  moderator_id :integer          not null, indexed
#
# Indexes
#
#  index_decisions_on_moderator_id  (moderator_id)
#
# Foreign Keys
#
#  fk_rails_...  (moderator_id => users.id)
#
