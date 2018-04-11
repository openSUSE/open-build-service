# frozen_string_literal: true

module Kiwi
  class Package < ApplicationRecord
    belongs_to :package_group
    has_one :kiwi_image, through: :package_groups

    validates :name, presence: { message: 'can\'t be blank' }

    def to_h
      hash = { name: name }
      hash[:arch] = arch if arch.present?
      hash[:replaces] = replaces if replaces.present?
      hash[:bootinclude] = bootinclude if bootinclude.present?
      hash[:bootdelete] = bootdelete if bootdelete.present?
      hash
    end
  end
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
# Foreign Keys
#
#  fk_rails_...  (package_group_id => kiwi_package_groups.id)
#
