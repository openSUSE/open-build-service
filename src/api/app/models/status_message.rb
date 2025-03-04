class StatusMessage < ApplicationRecord
  belongs_to :user # TODO: rename as creator
  has_many :status_message_acknowledgements, dependent: :destroy
  has_many :users, through: :status_message_acknowledgements

  validates :severity, :message, presence: true

  scope :announcements, -> { order('created_at DESC').where(severity: 'announcement') }
  scope :for_current_user, -> { where(communication_scope: communication_scopes_for_current_user) }
  scope :newest, -> { order('created_at DESC') }
  scope :for_severity, ->(severity) { where(severity: severity) if severity.present? }
  scope :for_communication_scope, ->(communication_scope) { where(communication_scope: communication_scope) if communication_scope.present? }

  enum :severity, { information: 0, green: 1, yellow: 2, red: 3, announcement: 4 }
  enum :communication_scope, { all_users: 0, logged_in_users: 1, admin_users: 2, in_beta_users: 3, in_rollout_users: 4 }
  alias_attribute :scope, :communication_scope

  def acknowledge!
    return false if acknowledged?

    users << User.session!
    RabbitmqBus.send_to_bus('metrics', "user.acknowledged_status_message status_message_id=#{id}")
    true
  end

  def acknowledged?
    users.include?(User.session!)
  end

  def self.latest_for_current_user
    announcement = StatusMessage.announcements.find_by(communication_scope: StatusMessage.communication_scopes_for_current_user)
    return nil unless announcement
    return nil if StatusMessageAcknowledgement.find_by(status_message: announcement, user: User.session)

    announcement
  end

  def self.communication_scopes_for_current_user
    scopes = [:all_users]
    return scopes unless User.session

    scopes << :admin_users if User.session.admin?
    scopes << :in_rollout_users if User.session.in_rollout?
    scopes << :in_beta_users if User.session.in_beta?
    scopes << :logged_in_users
  end
end

# == Schema Information
#
# Table name: status_messages
#
#  id                  :integer          not null, primary key
#  communication_scope :integer          default("all_users")
#  message             :text(65535)
#  severity            :integer
#  created_at          :datetime         indexed
#  user_id             :integer          indexed
#
# Indexes
#
#  index_status_messages_on_created_at  (created_at)
#  user                                 (user_id)
#
