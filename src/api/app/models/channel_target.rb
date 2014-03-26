class ChannelTarget < ActiveRecord::Base

  belongs_to :channel
  belongs_to :repository

  def self.find_by_repo(repo, projectFilter=nil)
    ct = []

    ChannelTarget.where(repository: repo).each do |c|
      ct << c if projectFilter.nil? or projectFilter.include?(c.channel.package.project)
    end
    return nil if ct.length < 1

    if ct.length > 1
      msg=""
      ct.each do |cti|
        msg << "#{cti.channel.package.project.name}/#{cti.channel.package.name}, "
      end
      raise "Multiple channel targets found in #{msg}"
    end
    return ct.first
  end

end
