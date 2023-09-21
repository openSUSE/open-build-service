class Decision < ApplicationRecord
  validates :reason, presence: true, length: { maximum: 65_535 }

  belongs_to :moderator, class_name: 'User', optional: false

  has_many :reports, dependent: :nullify

  enum kind: {
    cleared: 0,
    favor: 1
  }
end

# == Schema Information
#
# Table name: decisions
#
#  id           :bigint           not null, primary key
#  kind         :integer          default("cleared")
#  reason       :text(65535)      not null
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
