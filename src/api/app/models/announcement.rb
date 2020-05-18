class Announcement < ApplicationRecord
  DEFAULT_RENDER_PARAMS = { only: [:id, :message], dasherize: true, skip_types: true, skip_instruct: true }.freeze

  has_and_belongs_to_many :users

  default_scope { order(:created_at) }

  validates :message, presence: true

  # TODO: move to StatusMessage model after merge.
  enum communication_scope: { all_users: 0, logged_in_users: 1, admin_users: 2, in_beta_users: 3, in_rollout_users: 4 }
end
