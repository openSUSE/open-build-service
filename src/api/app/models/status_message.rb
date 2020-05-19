class StatusMessage < ApplicationRecord
  belongs_to :user # TODO: rename as creator
  has_many :status_message_acknowledgements, dependent: :destroy
  has_many :users, through: :status_message_acknowledgements

  validates :user, :severity, :message, presence: true

  scope :alive, -> { where(deleted_at: nil).order('created_at DESC') }
  scope :announcements, -> { alive.where(severity: 'announcement') }

  enum severity: { information: 0, green: 1, yellow: 2, red: 3, announcement: 4 }
  enum communication_scope: { all_users: 0, logged_in_users: 1, admin_users: 2, in_beta_users: 3, in_rollout_users: 4 }

  def delete
    self.deleted_at = Time.now
    save
  end

  def acknowledge!
    users << User.session!
  end

  def visible_for_current_user?
    current_user = User.possibly_nobody
    case communication_scope.try(:to_sym)
    when :admin_users
      current_user.is_admin?
    when :in_rollout_users
      current_user.in_rollout?
    when :in_beta_users
      current_user.in_beta?
    when :logged_in_users
      User.session.present?
    else # :all_users
      true
    end
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
