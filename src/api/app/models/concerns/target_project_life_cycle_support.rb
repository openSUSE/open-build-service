# We use this concern on BranchPackageStep and LinkPackageStep, because we need to react to closing and reopening a pull request for example
module TargetProjectLifeCycleSupport
  extend ActiveSupport::Concern

  def destroy_target_project
    EventSubscription.where(channel: 'scm', token: token, package: target_package).delete_all
    Project.find_by(name: target_project_name)&.destroy
  end

  def restore_target_project
    token_user_login = token.executor.login
    Project.restore(target_project_name, user: token_user_login)
    Workflows::ScmEventSubscriptionCreator.new(token, workflow_run, scm_webhook, target_package).call
  end
end
