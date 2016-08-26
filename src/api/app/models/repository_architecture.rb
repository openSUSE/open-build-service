class RepositoryArchitecture < ApplicationRecord
  belongs_to :repository,   inverse_of: :repository_architectures
  belongs_to :architecture, inverse_of: :repository_architectures

  acts_as_list scope: [:repository_id], top_of_list: 0

  validates :repository, :architecture, :position, presence: true
  validates :repository, uniqueness: { scope: :architecture }
end
