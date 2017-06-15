class ReleaseTarget < ApplicationRecord
  belongs_to :repository
  belongs_to :target_repository, class_name: 'Repository'

  enum trigger: { manual: 0, allsucceeded: 1, maintenance: 2 }
end

# == Schema Information
#
# Table name: release_targets
#
#  id                   :integer          not null, primary key
#  repository_id        :integer          not null, indexed
#  target_repository_id :integer          not null, indexed
#  trigger              :integer
#
# Indexes
#
#  index_release_targets_on_target_repository_id  (target_repository_id)
#  repository_id_index                            (repository_id)
#
# Foreign Keys
#
#  release_targets_ibfk_1  (repository_id => repositories.id)
#  release_targets_ibfk_2  (target_repository_id => repositories.id)
#
