class ReleaseTarget < ApplicationRecord
  belongs_to :repository
  belongs_to :target_repository, :class_name => 'Repository'
end
