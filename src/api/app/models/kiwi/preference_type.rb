class Kiwi::PreferenceType < ApplicationRecord
  belongs_to :image, inverse_of: :preference_type

  enum image_type: %i[btrfs clicfs cpio docker ext2 ext3 ext4 iso lxc oem product pxe reiserfs split squashfs tbz vmx xfs zfs]

  validates :image_type, inclusion: { in: image_types.keys }

  def containerconfig_xml
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.containerconfig(name: containerconfig_name, containerconfig_tag: containerconfig_tag)
    end
    builder.to_xml save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION | Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  # Can the user edit this from the kiwi editor?
  def editable?
    image_type == 'docker'
  end
end

# == Schema Information
#
# Table name: kiwi_preference_types
#
#  id                   :integer          not null, primary key
#  image_id             :integer          indexed
#  image_type           :integer
#  containerconfig_name :string(255)
#  containerconfig_tag  :string(255)
#
# Indexes
#
#  index_kiwi_preference_types_on_image_id  (image_id)
#
