module VerifyReleaseTargets
  extend ActiveSupport::Concern

  def verify_release_targets!(pro)
    repo_matches = nil
    repo_bad_type = nil

    pro.repositories.each do |repo|
      next if params[:repository] && params[:repository] != repo.name

      if params[:targetproject] || params[:targetrepository]
        target_repository = Repository.find_by_project_and_name(params[:targetproject], params[:targetrepository])

        check_single_target!(repo, target_repository)

        repo_matches = true
      else
        repo.release_targets.each do |releasetarget|
          next unless releasetarget

          unless releasetarget.trigger.in?(['manual', 'maintenance'])
            repo_bad_type = true
            next
          end

          check_single_target!(repo, releasetarget.target_repository)

          repo_matches = true
        end
      end
    end
    raise NoMatchingReleaseTarget, 'Trigger is not set to manual in any repository' if repo_bad_type && !repo_matches

    raise NoMatchingReleaseTarget, 'No defined or matching release target' unless repo_matches
  end

  private

  def check_single_target!(source_repository, target_repository)
    # checking write access and architectures
    raise UnknownRepository, 'Invalid source repository' unless source_repository
    raise UnknownRepository, 'Invalid target repository' unless target_repository
    raise CmdExecutionNoPermission, "no permission to write in project #{target_repository.project.name}" unless User.session!.can_modify?(target_repository.project)

    source_repository.check_valid_release_target!(target_repository)
  end
end
