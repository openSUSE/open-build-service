class PackageKind < ApplicationRecord
  belongs_to :package, optional: true
end

# == Schema Information
#
# Table name: package_kinds
#
#  id         :integer          not null, primary key
#  kind       :string           not null
#  package_id :integer          indexed
#
# Indexes
#
#  index_package_kinds_on_package_id  (package_id)
#
# Foreign Keys
#
#  package_kinds_ibfk_1  (package_id => packages.id)
#
