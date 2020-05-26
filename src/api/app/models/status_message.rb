class StatusMessage < ApplicationRecord
  belongs_to :user # TODO: rename as creator
  has_many :status_message_acknowledgements, dependent: :destroy
  has_many :users, through: :status_message_acknowledgements

  validates :user, :severity, :message, presence: true

  scope :alive, -> { where(deleted_at: nil).order('created_at DESC') }
  scope :announcements, -> { alive.where(severity: 'announcement') }

  enum severity: { information: 0, green: 1, yellow: 2, red: 3, announcement: 4 }
  enum communication_scope: { all_users: 0, logged_in_users: 1, admin_users: 2, in_beta_users: 3, in_rollout_users: 4 }

  # xml: A Nokogiri object
  def self.from_xml(xml)
    StatusMessage.create! if xml.blank?
    doc = Nokogiri::XML(xml, &:strict).root
    message = doc.css('message').text
    severity = doc.css('severity').text
    StatusMessage.new(message: message, severity: severity, user: User.session!)
  end

  def delete
    self.deleted_at = Time.now
    save
  end

  def acknowledge!
    users << User.session!
  end

  def self.newest_announcement_for_current_user
    announcement = StatusMessage.announcements.find_by(communication_scope: StatusMessage.communication_scopes_for_current_user)
    return nil unless announcement
    return nil if StatusMessageAcknowledgement.find_by(status_message: announcement, user: User.session)
    announcement
  end

  def self.communication_scopes_for_current_user
    scopes = [:all_users]
    return scopes unless User.session
    scopes << :admin_users if User.session.is_admin?
    scopes << :in_rollout_users if User.session.in_rollout?
    scopes << :in_beta_users if User.session.in_beta?
    scopes << :logged_in_users
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
