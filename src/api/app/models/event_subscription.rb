class EventSubscription < ActiveRecord::Base
  belongs_to :project
  belongs_to :package
  belongs_to :user

  validates :receive, inclusion: { in: %w(none all maintainer strictly_maintainer creator) }
  validate :only_package_or_project

  def only_package_or_project
    # only one can be set
    errors.add(:package_id, 'is conflicting with project_id') if self.package_id && self.project_id
  end

end

