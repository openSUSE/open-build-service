class ChannelTarget < ApplicationRecord
  belongs_to :channel
  belongs_to :repository
  has_one :project, through: :repository

  def self._sync_keys
    [:project, :repository]
  end

  def self.find_by_repo(repo, project_filter = nil)
    if project_filter.nil?
      ChannelTarget.distinct.where(repository: repo)
    else
      ChannelTarget.joins(channel: :package).
        distinct.
        where("repository_id = ? AND project_id IN (?)", repo, project_filter.map(&:id))
    end
  end
end

# == Schema Information
#
# Table name: channel_targets
#
#  id             :integer          not null, primary key
#  channel_id     :integer          not null, indexed => [repository_id]
#  repository_id  :integer          not null, indexed => [channel_id], indexed
#  prefix         :string(255)
#  id_template    :string(255)
#  disabled       :boolean          default(FALSE)
#  requires_issue :boolean
#
# Indexes
#
#  index_channel_targets_on_channel_id_and_repository_id  (channel_id,repository_id) UNIQUE
#  repository_id                                          (repository_id)
#
# Foreign Keys
#
#  channel_targets_ibfk_1  (channel_id => channels.id)
#  channel_targets_ibfk_2  (repository_id => repositories.id)
#
