class RepositoryArchitecture < ActiveRecord::Base
  belongs_to :repository
  belongs_to :architecture

  validate :repository, :architecture, :position, presence: true
end
