class RepositoryArchitecture < ActiveRecord::Base
  belongs_to :repository
  belongs_to :architecture
end
