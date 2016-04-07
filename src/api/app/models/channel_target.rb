class ChannelTarget < ActiveRecord::Base
  belongs_to :channel
  belongs_to :repository
  has_one :project, through: :repository

  class MultipleChannelTargets < APIException; end

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
    return nil if ct.length < 1

    if ct.length > 1
      msg=""
      ct.each do |cti|
        msg << "#{cti.channel.package.project.name}/#{cti.channel.package.name}, "
      end
      raise MultipleChannelTargets, "Multiple channel targets found in #{msg} for repository #{repo.project.name}/#{repo.name}"
    end
    return ct.first
  end
end
