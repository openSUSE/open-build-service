class Appeal < ApplicationRecord
  belongs_to :appellant, optional: false, class_name: 'User'
  belongs_to :decision, optional: false

  validates :reason, presence: true
  validates :reason, length: { maximum: 65_535 }

  validates :decision, uniqueness: { scope: :appellant }

  after_create :create_event

  private

  def create_event
    Event::AppealCreated.create(event_parameters)
  end

  def event_parameters
    { id: id, appellant_id: appellant.id, decision_id: decision.id, reason: reason,
      report_last_id: decision.reports.last.id, reportable_type: decision.reports.first.reportable.class.name }
  end
end

# == Schema Information
#
# Table name: appeals
#
#  id           :bigint           not null, primary key
#  reason       :text(65535)      not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  appellant_id :integer          not null, indexed, indexed => [decision_id]
#  decision_id  :bigint           not null, indexed => [appellant_id]
#
# Indexes
#
#  fk_rails_bd2c76ec6f           (appellant_id)
#  index_appeals_on_decision_id  (decision_id,appellant_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (appellant_id => users.id)
#  fk_rails_...  (decision_id => decisions.id)
#
