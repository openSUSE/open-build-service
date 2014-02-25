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

  def create_channel_package(pkg, maintenanceProject)
    channel = self.channel_binary_list.channel
    cp = channel.package
    name = channel.name

    # does it exist already? then just skip it
    return if Package.exists_by_project_and_name(pkg.project.name, name)

    # do we need to take care about a maintained list from upper project?
    if maintenanceProject and not maintenanceProject.maintained_projects.include? cp.project
      # not a maintained project here
      return
    end

    # create a package beside me
    tpkg = Package.new(:name => name, :title => cp.title, :description => cp.description)
    pkg.project.packages << tpkg
    tpkg.store

    # branch sources
    tpkg.branch_from(cp.project.name, cp.name)
    tpkg.sources_changed

    # branch repositories
    if channel.channel_targets.empty?
      # not defined in channel, so take all from project
      tpkg.project.branch_to_repositories_from(cp.project, cp, true)
    else
      # defined in channel
      channel.channel_targets.each do |ct|
        repo_name = ct.repository.extended_name
        # add repositories
        unless pkg.project.repositories.find_by_name(repo_name)
          tpkg.project.add_repository_with_targets(repo_name, ct.repository, [ct.repository]) 
        end
        # enable package
        tpkg.enable_for_repository repo_name
      end
    end
  end
end
