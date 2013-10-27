class RepositoryArchitecture < ActiveRecord::Base
  belongs_to :repository,   inverse_of: :repository_architectures
  belongs_to :architecture, inverse_of: :repository_architectures

  validate :repository, :architecture, :position, presence: true
end
