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
