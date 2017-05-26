class Project
  class BranchLocalRepositoriesCommand
    attr_reader :project, :pkg_to_enable, :opts

    def initialize(project, branch_project, pkg_to_enable, opts = {})
      @project = project
      @branch_project = branch_project
      @pkg_to_enable = pkg_to_enable
      @opts = opts
    end

    def run
      # shall we use the repositories from a different project?
      branch_project = @branch_project.update_instance('OBS', 'BranchRepositoriesFromProject')
      skip_repos = []
      a = branch_project.find_attribute('OBS', 'BranchSkipRepositories')
      skip_repos = a.values.map(&:value) if a
      branch_project.repositories.each do |repo|
        next if skip_repos.include? repo.name
        repo_name = opts[:extend_names] ? repo.extended_name : repo.name
        next if repo.is_local_channel?
        pkg_to_enable.enable_for_repository(repo_name) if pkg_to_enable
        next if project.repositories.find_by_name(repo_name)

        # copy target repository when operating on a channel
        targets = repo.release_targets if pkg_to_enable && pkg_to_enable.is_channel?
        # base is a maintenance incident, take its target instead (kgraft case)
        targets = repo.release_targets if repo.project.is_maintenance_incident?

        target_repos = []
        target_repos = targets.map(&:target_repository) if targets
        # or branch from official release project? release to it ...
        target_repos = [repo] if repo.project.is_maintenance_release?

        update_project = repo.project.update_instance
        if update_project != repo.project
          # building against gold master projects might happen (kgraft), but release
          # must happen to the right repos in the update project
          target_repos = Repository.find_by_project_and_path(update_project, repo)
        end

        project.add_repository_with_targets(repo_name, repo, target_repos, opts)
      end

      project.branch_copy_flags(branch_project)

      return unless pkg_to_enable.is_channel?

      # explicit call for a channel package, so create the repos for it
      pkg_to_enable.channels.each do |channel|
        channel.add_channel_repos_to_project(pkg_to_enable)
      end
    end
  end
end
