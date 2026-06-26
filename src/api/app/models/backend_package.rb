class BackendPackage < ApplicationRecord
  #### Includes and extends
  #### Constants
  #### Self config
  self.primary_key = 'package_id' # a package can have one target _link (or not)

  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :links_to, class_name: 'Package', optional: true
  belongs_to :package, inverse_of: :backend_package

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  scope :links, -> { where.not(links_to_id: nil) }
  scope :not_links, -> { where(links_to_id: nil) }

  #### Validations macros
  #### Class methods using self. (public and then private)

  # this is called from the UpdatePackageMetaJob and clockwork
  def self.refresh_dirty
    Package.dirty_backend_packages.distinct.pluck(:project_id).each do |project_id|
      UpdatePackagesIfDirtyJob.perform_later(project_id)
    end
  end

  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  #### Alias of methods
end

# == Schema Information
#
# Table name: backend_packages
#
#  changesmd5  :string(255)
#  error       :text(65535)
#  expandedmd5 :string(255)
#  maxmtime    :datetime
#  srcmd5      :string(255)
#  verifymd5   :string(255)
#  updated_at  :datetime
#  links_to_id :integer          indexed
#  package_id  :integer          not null, primary key
#
# Indexes
#
#  index_backend_packages_on_links_to_id  (links_to_id)
#
# Foreign Keys
#
#  backend_packages_ibfk_1  (package_id => packages.id)
#  backend_packages_ibfk_2  (links_to_id => packages.id)
#
