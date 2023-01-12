module ScmSyncEnabledStep
  def set_scmsync_on_target_package
    # only change the fragment here and leave the query alone!
    parsed_scmsync_url = Addressable::URI.parse(scmsync_url)
    parsed_scmsync_url.fragment = scm_webhook.payload[:commit_sha]

    # if we use scmsync to sync a whole project, then each package will be
    # fetched from a subdirectory
    if scm_synced_project?
      query = parsed_scmsync_url.query_values || {}
      query['subdir'] = source_package_name
      parsed_scmsync_url.query_values = query
    end

    target_package.update(scmsync: parsed_scmsync_url.to_s)
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
