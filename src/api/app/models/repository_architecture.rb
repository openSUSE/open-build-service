class RepositoryArchitecture < ActiveRecord::Base
  belongs_to :repository
  belongs_to :architecture

  attr_accessible :repository, :architecture, :position
  validate :repository, :architecture, :position, presence: true
end
