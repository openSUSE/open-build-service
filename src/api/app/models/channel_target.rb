class ChannelTarget < ActiveRecord::Base

  belongs_to :channel
  belongs_to :repository

  def self.find_by_repo(repo, projectFilter=nil)
    ct = []

    ct = ChannelTarget.distinct.where(repository: repo).select do |c|
      c if projectFilter.nil? or projectFilter.include?(c.channel.package.project)
    end

    return nil if ct.empty?

    msg=""
    ct.each do |cti|
        msg << "#{cti.channel.package.project.name}/#{cti.channel.package.name}, "
    end
    # i dont get it. you raise it always? 
    raise "Multiple channel targets found in #{msg} for repository #{repo.project.name}/#{repo.name}"
    ct.first
  end

end
