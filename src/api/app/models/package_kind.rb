class PackageKind < ApplicationRecord
  belongs_to :package
end

# == Schema Information
#
# Table name: package_kinds
#
#  id         :integer          not null, primary key
#  package_id :integer
#  kind       :string(9)        not null
#
# Indexes
#
#  index_package_kinds_on_package_id  (package_id)
#
