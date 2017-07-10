class Kiwi::PackageGroup < ApplicationRecord
  has_many :packages
  belongs_to :image

  # we need to add a prefix, to avoid generating class methods that already
  # exist in Active Record, such as "delete"
  enum kiwi_type: %i[bootstrap delete docker image iso lxc oem pxe split testsuite vmx], _prefix: :type

  validates :kiwi_type, presence: true, inclusion: { in: kiwi_types.keys }
end

# == Schema Information
#
# Table name: kiwi_package_groups
#
#  id           :integer          not null, primary key
#  kiwi_type    :integer          not null
#  profiles     :string(255)
#  pattern_type :string(255)
#  image_id     :integer          indexed
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_kiwi_package_groups_on_image_id  (image_id)
#
