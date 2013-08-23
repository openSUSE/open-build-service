class ChannelBinary < ActiveRecord::Base

  belongs_to :channel_binary_list
  belongs_to :project
  belongs_to :repository
  belongs_to :architecture

  def self.find_by_project_and_package( project, package )
    project = Project.find_by_name(project) if project.class == String
    cbs = Array.new
    # find direct refences
    cbs += ChannelBinary.where(project: project, package: package)
    # find refences where project comes from the default
    cbs += ChannelBinary.joins(:channel_binary_list).where("channel_binaries.project_id = NULL and channel_binary_lists.project_id = ? and package = ?", project, package)
    return cbs
  end

end
