class ChannelTarget < ApplicationRecord
  belongs_to :channel
  belongs_to :repository
  has_one :project, through: :repository

  def self._sync_keys
    [:project, :repository]
  end

  def self.find_by_repo(repo, projectFilter = nil)
    if projectFilter.nil?
      ChannelTarget.distinct.where(repository: repo)
    else
      ChannelTarget.joins(channel: :package).
        distinct.
        where("repository_id = ? AND project_id IN (?)", repo, projectFilter.map(&:id))
    end
  end
end

# == Schema Information
#
# Table name: channel_targets
#
#  id             :integer          not null, primary key
#  channel_id     :integer          not null
#  repository_id  :integer          not null
#  id_template    :string(255)
#  disabled       :boolean          default("0")
#  requires_issue :boolean
#
# Indexes
#
#  index_channel_targets_on_channel_id_and_repository_id  (channel_id,repository_id) UNIQUE
#  repository_id                                          (repository_id)
#
