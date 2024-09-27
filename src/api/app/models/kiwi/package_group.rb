module Kiwi
  class PackageGroup < ApplicationRecord
    has_many :packages, dependent: :destroy, index_errors: true
    belongs_to :image, inverse_of: :package_groups, optional: true

    # we need to add a prefix, to avoid generating class methods that already
    # exist in Active Record, such as "delete"
    enum :kiwi_type, {
      bootstrap: 0,
      delete: 1,
      docker: 2,
      image: 3,
      iso: 4,
      lxc: 5,
      oem: 6,
      pxe: 7,
      split: 8,
      testsuite: 9,
      vmx: 10
    }, prefix: :type

    scope :type_image, -> { where(kiwi_type: :image) }

    validates :kiwi_type, presence: true

    accepts_nested_attributes_for :packages, reject_if: :all_blank, allow_destroy: true

    def to_xml
      return '' if packages.empty?

      group_attributes = { type: kiwi_type }
      group_attributes[:profiles] = profiles if profiles.present?
      group_attributes[:patternType] = pattern_type if pattern_type.present?

      builder = Nokogiri::XML::Builder.new
      builder.packages(group_attributes) do |group|
        packages.each do |package|
          group.package(package.to_h)
        end
      end

      builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION | Nokogiri::XML::Node::SaveOptions::FORMAT)
    end

    def kiwi_type_image?
      kiwi_type == 'image'
    end
  end
end

# == Schema Information
#
# Table name: kiwi_package_groups
#
#  id           :integer          not null, primary key
#  kiwi_type    :integer          not null
#  pattern_type :string(255)
#  profiles     :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  image_id     :integer          indexed
#
# Indexes
#
#  index_kiwi_package_groups_on_image_id  (image_id)
#
# Foreign Keys
#
#  fk_rails_...  (image_id => kiwi_images.id)
#
