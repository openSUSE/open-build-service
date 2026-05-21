module ScmSyncEnabledStep
  def parse_scmsync_for_target_package
    return unless scm_synced?

    # only change the fragment here and leave the query alone!
    parsed_scmsync_url = Addressable::URI.parse(scmsync_url)
    parsed_scmsync_url.fragment = workflow_run.commit_sha

    # if we use scmsync to sync a whole project, then each package will be
    # fetched from a subdirectory
    if scm_synced_project?
      query = parsed_scmsync_url.query_values || {}
      query['subdir'] = step_instructions[:source_package]
      parsed_scmsync_url.query_values = query
    end

    parsed_scmsync_url.to_s
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
    Package.get_by_project_and_name(step_instructions[:source_project], step_instructions[:source_package]).try(:scmsync)
  rescue Project::Errors::UnknownObjectError, Package::Errors::UnknownObjectError
    nil
  end

  def scm_synced_project_url
    Project.get_by_name(step_instructions[:source_project]).try(:scmsync)
  rescue Project::Errors::UnknownObjectError
    nil
  end
end
