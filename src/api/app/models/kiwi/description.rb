class Kiwi::Description < ApplicationRecord
  belongs_to :image, inverse_of: :description, optional: true

  enum :description_type, {
    system: 0
  }

  validates :description_type, inclusion: { in: description_types.keys }

  def to_xml
    builder = Nokogiri::XML::Builder.new
    builder.description(type: description_type) do |description|
      description.author(author)
      description.contact(contact)
      description.specification(specification)
    end
    builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION | Nokogiri::XML::Node::SaveOptions::FORMAT)
  end
end

# == Schema Information
#
# Table name: kiwi_descriptions
#
#  id               :integer          not null, primary key
#  author           :string(255)
#  contact          :string(255)
#  description_type :integer          default("system")
#  specification    :string(255)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  image_id         :integer          indexed
#
# Indexes
#
#  index_kiwi_descriptions_on_image_id  (image_id)
#
