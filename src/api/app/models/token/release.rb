class Token::Release < Token
  include MaintenanceHelper

  def call(options)
    set_triggered_at
    return unless options[:package]

    # uniq timestring for all targets
    time_now = Time.now.utc

    package_to_release = options[:package]
    if options[:targetproject].present? && options[:targetrepository].present? && options[:filter_source_repository].present?
      source_repository = Repository.find_by_project_and_name(options[:project].name, options[:filter_source_repository])
      target_repository = Repository.find_by_project_and_name(options[:targetproject], options[:targetrepository])
      raise InsufficientPermissionOnTargetRepository, "no permission to write in project #{target_repository.project.name}" unless User.session!.can_modify?(target_repository.project)

      release(package_to_release, source_repository, target_repository, time_now, options)
      return
    end

    release_manually_triggered_targets(package_to_release, time_now, options)
  end

  def package_find_options
    { follow_project_links: false, follow_multibuild: true }
  end

  private

  def release(package_to_release, source_repository, target_repository, time_now, options)
    opts = { filter_source_repository: source_repository,
             manual: true,
             comment: 'Releasing via trigger event' }
    opts[:multibuild_container] = options[:multibuild_flavor] if options[:multibuild_flavor].present?
    opts[:filter_architecture] = options[:arch] if options[:arch].present?

    if package_to_release.present?
      release_package(package_to_release,
                      target_repository,
                      package_to_release.release_target_name(target_repository, time_now),
                      opts)
    else
      @project.do_project_release(opts)
    end
  end

  def release_manually_triggered_targets(package_to_release, time_now, options)
    manual_release_targets = package_to_release.project.release_targets.where(trigger: 'manual')
    raise NoReleaseTargetFound, "#{package_to_release.project} has no release targets that are triggered manually" unless manual_release_targets.any?

    # releasing ...
    manual_release_targets.each do |release_target|
      next if options[:filter_source_repository].present? && options[:filter_source_repository] == release_target.repository.name

      release_target.repository.check_valid_release_target!(release_target.target_repository, options[:arch])
      release(package_to_release, release_target.repository, release_target.target_repository, time_now, options)
    end
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id                          :integer          not null, primary key
#  description                 :string(64)       default("")
#  enabled                     :boolean          default(TRUE), not null, indexed
#  scm_token                   :string(255)      indexed
#  string                      :string(255)      indexed
#  triggered_at                :datetime
#  type                        :string(255)
#  workflow_configuration_path :string(255)      default(".obs/workflows.yml")
#  workflow_configuration_url  :string(8192)
#  executor_id                 :integer          not null, indexed
#  package_id                  :integer          indexed
#
# Indexes
#
#  index_tokens_on_enabled    (enabled)
#  index_tokens_on_scm_token  (scm_token)
#  index_tokens_on_string     (string) UNIQUE
#  package_id                 (package_id)
#  user_id                    (executor_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (executor_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
