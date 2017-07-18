class Kiwi::Package < ApplicationRecord
  belongs_to :package_group

  validates :name, presence: true
end

# == Schema Information
#
# Table name: kiwi_packages
#
#  id               :integer          not null, primary key
#  name             :string(255)      not null
#  arch             :string(255)
#  replaces         :string(255)
#  bootinclude      :boolean
#  bootdelete       :boolean
#  package_group_id :integer          indexed
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_kiwi_packages_on_package_group_id  (package_group_id)
#
