class BlockedUser < ApplicationRecord
  belongs_to :blocker, class_name: 'User', optional: false
  belongs_to :blocked, class_name: 'User', optional: false

  validates :blocked_id, uniqueness: { scope: :blocker_id, message: 'This user is already blocked.' }
end

# == Schema Information
#
# Table name: blocked_users
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  blocked_id :integer          not null, indexed, indexed => [blocker_id]
#  blocker_id :integer          not null, indexed => [blocked_id]
#
# Indexes
#
#  index_blocked_users_on_blocked_id                 (blocked_id)
#  index_blocked_users_on_blocker_id_and_blocked_id  (blocker_id,blocked_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (blocked_id => users.id)
#  fk_rails_...  (blocker_id => users.id)
#
