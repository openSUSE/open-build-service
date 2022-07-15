module ScmSyncEnabledStep
  extend ActiveSupport::Concern

  def set_scmsync_on_target_package
    updated_scmsync_url = if scmsync_url.include?('subdir=') || scm_synced_project?
                            "#{scmsync_url}?subdir=#{source_package_name}##{scm_webhook.payload[:commit_sha]}"
                          else
                            "#{scmsync_url}##{scm_webhook.payload[:commit_sha]}"
                          end
    target_package.update(scmsync: updated_scmsync_url)
  end

  def scm_synced?
    scm_synced_project? || scm_synced_package?
  end

  def scmsync_url
    return scm_synced_package_url if scm_synced_package?

    scm_synced_project_url
  end

  def scm_synced_package?
    scm_synced_package_url.present?
  end

  def scm_synced_project?
    scm_synced_project_url.present?
  end

  def scm_synced_package_url
    Package.get_by_project_and_name(source_project_name, source_package_name).try(:scmsync)
  end

  def scm_synced_project_url
    Project.get_by_name(source_project_name).try(:scmsync)
  end
end
