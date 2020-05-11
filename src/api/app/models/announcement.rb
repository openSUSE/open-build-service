class Announcement < ApplicationRecord
  DEFAULT_RENDER_PARAMS = { only: [:id, :message], dasherize: true, skip_types: true, skip_instruct: true }.freeze

  has_and_belongs_to_many :users

  default_scope { order(:created_at) }

  validates :message, presence: true
end
