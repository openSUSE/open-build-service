class Decision < ApplicationRecord
  TYPES = { favored: 'DecisionFavored', cleared: 'DecisionCleared' }.freeze

  validates :reason, presence: true, length: { maximum: 65_535 }
  validates :type, presence: true, length: { maximum: 255 }

  belongs_to :moderator, class_name: 'User', optional: false

  has_many :reports, dependent: :nullify

  # TODO: Remove this after type is deployed
  enum kind: {
    cleared: 0,
    favor: 1
  }

  after_create :create_event
  after_create :track_decision

  def description
    'The moderator decided on the report'
  end

  private

  # TODO: Replace this with `AbstractMethodCalled` after type is deployed
  def create_event
    case kind
    when 'cleared'
      Event::ClearedDecision.create(event_parameters)
    else
      Event::FavoredDecision.create(event_parameters)
    end
  end

  def event_parameters
    { id: id, moderator_id: moderator.id, reason: reason, report_last_id: reports.last.id, reportable_type: reports.first.reportable.class.name }
  end

  # TODO: Remove kind after type is deployed
  def track_decision
    RabbitmqBus.send_to_bus('metrics', "decision,kind=#{kind},type=#{type} hours_before_decision=#{hours_before_decision},count=1")
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
#  kind         :integer          default("cleared")
#  reason       :text(65535)      not null
#  type         :string(255)      not null, default("DecisionCleared")
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
