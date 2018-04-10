# frozen_string_literal: true

class Kiwi::Description < ApplicationRecord
  belongs_to :image, inverse_of: :description

  enum description_type: [:system]

  validates :description_type, inclusion: { in: description_types.keys }

  def to_xml
    builder = Nokogiri::XML::Builder.new
    builder.description(type: description_type) do |description|
      description.author(author)
      description.contact(contact)
      description.specification(specification)
    end
    builder.to_xml save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION | Nokogiri::XML::Node::SaveOptions::FORMAT
  end
end

# == Schema Information
#
# Table name: kiwi_descriptions
#
#  id               :integer          not null, primary key
#  image_id         :integer          indexed
#  description_type :integer          default("system")
#  author           :string(255)
#  contact          :string(255)
#  specification    :string(255)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_kiwi_descriptions_on_image_id  (image_id)
#
