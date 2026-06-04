class NotifiedPackage < ApplicationRecord
  belongs_to :notification

  validates :notification_id, uniqueness: { scope: :package_name }
  validates :package_name, presence: true, length: { maximum: 255 }

  scope :for_user_web_notifications, ->(user) {
    joins(:notification)
      .merge(user.notifications.for_web)
      .distinct
  }
end

# == Schema Information
#
# Table name: notified_packages
#
#  id              :bigint           not null, primary key
#  package_name    :string(255)      not null, uniquely indexed => [notification_id], indexed
#  created_at      :datetime         not null
#  notification_id :bigint           not null, uniquely indexed => [package_name]
#
# Indexes
#
#  index_notified_packages_on_notification_id_and_package_name  (notification_id,package_name) UNIQUE
#  index_notified_packages_on_package_name                      (package_name)
#
# Foreign Keys
#
#  fk_rails_...  (notification_id => notifications.id)
#
