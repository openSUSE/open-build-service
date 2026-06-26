# We use this concern on BranchPackageStep and LinkPackageStep, because we need to react to closing and reopening a pull request for example
module TargetProjectLifeCycleSupport
  extend ActiveSupport::Concern

  def destroy_target_project
    return unless target_project

    Pundit.authorize(@token.executor, target_project, :destroy?)

    EventSubscription.where(channel: 'scm', token: token, package: target_package).delete_all
    target_project.destroy
  end

  def restore_target_project
    return if target_project

    project_to_restore = Project.new(name: target_project_name)

    Pundit.authorize(@token.executor, project_to_restore, :create?)

    Project.restore(target_project_name, user: token.executor.login)
    Workflows::ScmEventSubscriptionCreator.new(token, workflow_run, target_package).call
  end
end
