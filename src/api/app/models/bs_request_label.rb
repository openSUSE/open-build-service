class BsRequestLabel < ApplicationRecord
  validates :name, presence: true
  validates :name, uniqueness: true
  validates :name, length: { maximum: 50 }
  validates :description, length: { maximum: 255 }

  has_many :bs_request_bs_request_labels
  has_many :bs_requests, through: :bs_request_bs_request_labels
end

# == Schema Information
#
# Table name: bs_request_labels
#
#  id          :integer          not null, primary key
#  description :text(65535)
#  name        :string(255)      not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
