# Report class flags abusive content, be it projects, packages, users or comments
class Report < ApplicationRecord
  validates :reason, length: { maximum: 65_535 }
  validates :reportable_type, length: { maximum: 255 }

  belongs_to :user, optional: false
  belongs_to :reportable, polymorphic: true, optional: false
end

# == Schema Information
#
# Table name: reports
#
#  id              :bigint           not null, primary key
#  reason          :text(65535)
#  reportable_type :string(255)      indexed => [reportable_id]
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  reportable_id   :integer          indexed => [reportable_type]
#  user_id         :integer          not null, indexed
#
# Indexes
#
#  index_reports_on_reportable  (reportable_type,reportable_id)
#  index_reports_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
