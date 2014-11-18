class ChannelBinary < ActiveRecord::Base

  belongs_to :channel_binary_list
  belongs_to :project
  belongs_to :repository
  belongs_to :architecture

  def self.find_by_project_and_package(project, package)
    project = Project.find_by_name(project) if project.is_a? String

    # I am not able to construct this with rails in a valid way :/
    return ChannelBinary.find_by_sql(['SELECT channel_binaries.* FROM channel_binaries LEFT JOIN channel_binary_lists ON channel_binary_lists.id = channel_binaries.channel_binary_list_id WHERE (channel_binary_lists.project_id = ? and package = ?)', project.id, package])
  end

  def create_channel_package_into(project)
    channel = self.channel_binary_list.channel

    # does it exist already? then just skip it
    return if Package.exists_by_project_and_name(project.name, channel.name)

    # create a channel package beside my package
    channel.branch_channel_package_into_project(project)
  end

end
