class BackendPackage < ActiveRecord::Base
  # a package can have one target _link (or not)
  self.primary_key = 'package_id'
  belongs_to :links_to, class_name: "Package"
  belongs_to :package, class_name: "Package"

  scope :links, -> { where("links_to_id is not null") }
end
