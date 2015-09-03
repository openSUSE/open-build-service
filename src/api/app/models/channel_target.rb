class ChannelTarget < ActiveRecord::Base

  belongs_to :channel
  belongs_to :repository

  class MultipleChannelTargets < APIException; end

  def self._sync_keys
    [ :repository ]
  end

  def self.find_by_repo(repo, projectFilter=nil)
    ct = []

    ChannelTarget.distinct.where(repository: repo).each do |c|
      ct << c if projectFilter.nil? or projectFilter.include?(c.channel.package.project)
    end
    return nil if ct.length < 1

    if ct.length > 1
      msg=""
      ct.each do |cti|
        msg << "#{cti.channel.package.project.name}/#{cti.channel.package.name}, "
      end
      raise MultipleChannelTargets "Multiple channel targets found in #{msg} for repository #{repo.project.name}/#{repo.name}"
    end
    return ct.first
  end

end
