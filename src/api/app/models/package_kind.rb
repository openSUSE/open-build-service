class PackageKind < ApplicationRecord
  belongs_to :package

  enum kind: { patchinfo: 0, aggregate: 1, link: 2, channel: 3, product: 4 }
end

# == Schema Information
#
# Table name: package_kinds
#
#  id         :integer          not null, primary key
#  package_id :integer          indexed
#  kind       :integer          not null
#
# Indexes
#
#  index_package_kinds_on_package_id  (package_id)
#
# Foreign Keys
#
#  package_kinds_ibfk_1  (package_id => packages.id)
#
