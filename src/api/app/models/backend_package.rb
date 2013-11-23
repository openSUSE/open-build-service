class BackendPackage < ActiveRecord::Base
  # a package can have one target _link (or not)
  self.primary_key = 'package_id'
  belongs_to :links_to, class_name: "Package"
  belongs_to :package, class_name: "Package"

  scope :links, -> { where("links_to_id is not null") }
  scope :not_links, -> { where("links_to_id is null") }

  # this is called from the UpdatePackageMetaJob and clockwork
  def self.refresh_dirty
    Package.dirty_backend_package.pluck(:project_id).uniq.each do |p|
      Project.find(p).delay(priority: 10).update_packages_if_dirty
    end
  end
end
