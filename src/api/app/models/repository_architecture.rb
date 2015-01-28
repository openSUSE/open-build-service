class RepositoryArchitecture < ActiveRecord::Base
  belongs_to :repository,   inverse_of: :repository_architectures
  belongs_to :architecture, inverse_of: :repository_architectures

  validates :repository, :architecture, :position, presence: true
end
