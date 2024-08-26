class Kiwi::Preference < ApplicationRecord
  belongs_to :image, inverse_of: :preferences, optional: true

  enum :type_image, {
    btrfs: 0,
    clicfs: 1,
    cpio: 2,
    docker: 3,
    ext2: 4,
    ext3: 5,
    ext4: 6,
    iso: 7,
    lxc: 8,
    oem: 9,
    product: 10,
    pxe: 11,
    reiserfs: 12,
    split: 13,
    squashfs: 14,
    tbz: 15,
    vmx: 16,
    xfs: 17,
    zfs: 18
  }, prefix: :image_type

  validates :type_image, inclusion: { in: type_images.keys }, allow_nil: true
  validates :version, format: { with: /\A[\d.]+\z/ }

  def containerconfig_xml
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.containerconfig(name: type_containerconfig_name, type_containerconfig_tag: type_containerconfig_tag)
    end
    builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION | Nokogiri::XML::Node::SaveOptions::FORMAT)
  end

  # Can the user edit this from the kiwi editor?
  def containerconfig_fields_editable?
    type_image == 'docker'
  end
end

# == Schema Information
#
# Table name: kiwi_preferences
#
#  id                        :integer          not null, primary key
#  profile                   :string(191)
#  type_containerconfig_name :string(255)
#  type_containerconfig_tag  :string(255)
#  type_image                :integer
#  version                   :string(255)
#  image_id                  :integer          indexed
#
# Indexes
#
#  index_kiwi_preferences_on_image_id  (image_id)
#
