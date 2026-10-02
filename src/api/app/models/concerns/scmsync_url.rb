module ScmsyncUrl
  extend ActiveSupport::Concern

  COMMIT_SHA_PATTERN = /\A\h{40}\z/
  SCM_PROVIDER_MATCHERS = {
    github: /(^|\.)github(\.|$)/,
    gitlab: /(^|\.)gitlab(\.|$)/,
    gitea: /(^|\.)gitea(\.|$)|\Asrc\.opensuse\.org\z/
  }.freeze

  # OBS stores clone URLs and adds query params like `subdir` for SCM synced
  # projects. Translate them into provider browse URLs for WebUI links.
  def scmsync_url
    return if scmsync.blank?

    build_scmsync_url(Addressable::URI.parse(scmsync))
  rescue Addressable::URI::InvalidURIError
    scmsync
  end

  private

  def build_scmsync_url(parsed_scmsync_url)
    revision = parsed_scmsync_url.fragment
    subdir = parsed_scmsync_url.query_values&.fetch('subdir', nil)&.delete_prefix('/')

    normalize_scmsync_url!(parsed_scmsync_url)

    return fallback_scmsync_url(parsed_scmsync_url, revision) if revision.blank?

    translated_scmsync_url(parsed_scmsync_url, revision, subdir) || fallback_scmsync_url(parsed_scmsync_url, revision)
  end

  def normalize_scmsync_url!(parsed_scmsync_url)
    parsed_scmsync_url.query = nil
    parsed_scmsync_url.fragment = nil
    parsed_scmsync_url.path = parsed_scmsync_url.path.chomp('/').delete_suffix('.git')
  end

  def translated_scmsync_url(parsed_scmsync_url, revision, subdir)
    case scmsync_provider(parsed_scmsync_url)
    when :github
      github_scmsync_url(parsed_scmsync_url, revision, subdir)
    when :gitlab
      gitlab_scmsync_url(parsed_scmsync_url, revision, subdir)
    when :gitea
      gitea_scmsync_url(parsed_scmsync_url, revision, subdir)
    end
  end

  def fallback_scmsync_url(parsed_scmsync_url, revision)
    parsed_scmsync_url.fragment = revision
    parsed_scmsync_url.to_s
  end

  def scmsync_provider(parsed_scmsync_url)
    host = parsed_scmsync_url.host.to_s.downcase

    provider = SCM_PROVIDER_MATCHERS.find { |_provider, matcher| host.match?(matcher) }
    provider&.first
  end

  def github_scmsync_url(parsed_scmsync_url, revision, subdir)
    parsed_scmsync_url.path = if subdir.present?
                                "#{parsed_scmsync_url.path}/tree/#{revision}/#{subdir}"
                              elsif commit_sha?(revision)
                                "#{parsed_scmsync_url.path}/commit/#{revision}"
                              else
                                "#{parsed_scmsync_url.path}/tree/#{revision}"
                              end
    parsed_scmsync_url.to_s
  end

  def gitlab_scmsync_url(parsed_scmsync_url, revision, subdir)
    parsed_scmsync_url.path = if subdir.present?
                                "#{parsed_scmsync_url.path}/-/tree/#{revision}/#{subdir}"
                              elsif commit_sha?(revision)
                                "#{parsed_scmsync_url.path}/-/commit/#{revision}"
                              else
                                "#{parsed_scmsync_url.path}/-/tree/#{revision}"
                              end
    parsed_scmsync_url.to_s
  end

  def gitea_scmsync_url(parsed_scmsync_url, revision, subdir)
    parsed_scmsync_url.path = if subdir.present?
                                route = commit_sha?(revision) ? 'commit' : 'branch'
                                "#{parsed_scmsync_url.path}/src/#{route}/#{revision}/#{subdir}"
                              elsif commit_sha?(revision)
                                "#{parsed_scmsync_url.path}/commit/#{revision}"
                              else
                                "#{parsed_scmsync_url.path}/src/branch/#{revision}"
                              end
    parsed_scmsync_url.to_s
  end

  def commit_sha?(revision)
    revision.match?(COMMIT_SHA_PATTERN)
  end
end
