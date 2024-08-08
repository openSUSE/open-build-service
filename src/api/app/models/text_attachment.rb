class TextAttachment < ApplicationRecord
  belongs_to :attachable, polymorphic: true, optional: false

  validates :attachable_id, uniqueness: { scope: %i[attachable_type category] }
  validates :attachable_type, length: { maximum: 255 }
  validates :category, presence: true
  validates :content, length: { maximum: 65_535 }

  enum category: {
    contribution_guide: 0,
    security_policy: 1
  }
end

# == Schema Information
#
# Table name: text_attachments
#
#  attachable_type :string(255)      not null, indexed => [attachable_id, category]
#  category        :integer          not null, indexed => [attachable_type, attachable_id]
#  content         :text(65535)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  attachable_id   :integer          not null, indexed => [attachable_type, category]
#
# Indexes
#
#  index_text_attachment_on_attachables_and_category  (attachable_type,attachable_id,category) UNIQUE
#
