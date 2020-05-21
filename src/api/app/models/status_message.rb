class StatusMessage < ApplicationRecord
  belongs_to :user # TODO: rename as creator
  has_many :status_message_acknowledgements, dependent: :destroy
  has_many :users, through: :status_message_acknowledgements

  validates :user, :severity, :message, presence: true

  scope :alive, -> { where(deleted_at: nil).order('created_at DESC') }
  scope :announcements, -> { alive.where(severity: 'announcement') }

  enum severity: { information: 0, green: 1, yellow: 2, red: 3, announcement: 4 }

  def delete
    self.deleted_at = Time.now
    save
  end

  def acknowledge!
    users << User.session!
  end
end

# == Schema Information
#
# Table name: status_messages
#
#  id         :integer          not null, primary key
#  created_at :datetime         indexed => [deleted_at]
#  deleted_at :datetime         indexed => [created_at]
#  message    :text(65535)
#  user_id    :integer          indexed
#  severity   :integer
#
# Indexes
#
#  index_status_messages_on_deleted_at_and_created_at  (deleted_at,created_at)
#  user                                                (user_id)
#
