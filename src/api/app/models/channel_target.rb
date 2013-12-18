class ChannelTarget < ActiveRecord::Base

  belongs_to :channel
  belongs_to :repository

  def self.find_by_repo(repo, projectFilter=nil)
    ct = []

    ChannelTarget.where(repository: repo).each do |c|
      ct << c if projectFilter.nil? or projectFilter.include?(c.channel.package.project)
    end
    return nil if ct.length < 1

    raise "Multiple channel targets found" if ct.length > 1
    return ct.first
  end

end
