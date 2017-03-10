class ReleaseTarget < ApplicationRecord
  belongs_to :repository
  belongs_to :target_repository, class_name: 'Repository'
end

# == Schema Information
#
# Table name: release_targets
#
#  id                   :integer          not null, primary key
#  repository_id        :integer          not null
#  target_repository_id :integer          not null
#  trigger              :string(12)
#
# Indexes
#
#  index_release_targets_on_target_repository_id  (target_repository_id)
#  repository_id_index                            (repository_id)
#
