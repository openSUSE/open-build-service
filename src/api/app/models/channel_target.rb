class ChannelTarget < ActiveRecord::Base
  belongs_to :channel
  belongs_to :repository
  has_one :project, through: :repository

  def self._sync_keys
    [ :project, :repository ]
  end

  def self.find_by_repo(repo, projectFilter = nil)
    ct = []

    if projectFilter.nil?
      ct = ChannelTarget.distinct.where(repository: repo)
    else
      ct = ChannelTarget.joins(:channel => :package).distinct.where("repository_id = ? AND project_id IN (?)", repo, projectFilter.map{|p| p.id})
    end

    ct
  end
end
