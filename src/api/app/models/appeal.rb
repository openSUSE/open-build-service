class Appeal < ApplicationRecord
  belongs_to :appellant, optional: false, class_name: 'User'
  belongs_to :decision, optional: false

  validates :reason, presence: true
end

# == Schema Information
#
# Table name: appeals
#
#  id           :bigint           not null, primary key
#  reason       :text(65535)      not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  appellant_id :integer          not null, indexed
#  decision_id  :bigint           not null, indexed
#
# Indexes
#
#  fk_rails_5fe229ec9a  (decision_id)
#  fk_rails_bd2c76ec6f  (appellant_id)
#
# Foreign Keys
#
#  fk_rails_...  (appellant_id => users.id)
#  fk_rails_...  (decision_id => decisions.id)
#
