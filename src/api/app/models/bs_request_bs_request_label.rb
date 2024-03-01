class BsRequestBsRequestLabel < ApplicationRecord
  belongs_to :bs_request, required: true
  belongs_to :bs_request_label, required: true

  validates :bs_request_id, uniqueness: { scope: :bs_request_label_id }
end

# == Schema Information
#
# Table name: bs_request_bs_request_labels
#
#  id                  :integer          not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  bs_request_id       :integer          not null, indexed
#  bs_request_label_id :integer          not null, indexed
#
# Indexes
#
#  index_bs_request_bs_request_labels_on_bs_request_id        (bs_request_id)
#  index_bs_request_bs_request_labels_on_bs_request_label_id  (bs_request_label_id)
#
# Foreign Keys
#
#  fk_rails_...  (bs_request_id => bs_requests.id)
#  fk_rails_...  (bs_request_label_id => bs_request_labels.id)
#
