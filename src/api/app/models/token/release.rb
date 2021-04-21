class Token::Release < Token
  # TODO: refactor this out of the helper
  # to get access to the method release_package
  include MaintenanceHelper

  def self.token_name
    'release'
  end

  # TODO: Use package_from_association_or_params instead of package
  def call(_params)
    # AUTHORIZATION
    raise NoPermissionForPackage.setup('no_permission', 403, "no permission for package #{package} in project #{package.project}") unless policy(package).update?

    manual_release_targets = package.project.release_targets.where(trigger: 'manual')
    # AUTHORIZATION
    raise NoPermissionForPackage.setup('not_found', 404, "#{package.project} has no release targets that are triggered manually") unless manual_release_targets.any?

    manual_release_targets.each do |release_target|
      release_package(package,
                      release_target.target_repository,
                      package.release_target_name,
                      { filter_source_repository: release_target.repository,
                        manual: true,
                        comment: 'Releasing via trigger event' })
    end
  end

  def package_find_options
    { use_source: true, follow_project_links: false, follow_multibuild: false }
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id         :integer          not null, primary key
#  string     :string(255)      indexed
#  type       :string(255)
#  package_id :integer          indexed
#  user_id    :integer          not null, indexed
#
# Indexes
#
#  index_tokens_on_string  (string) UNIQUE
#  package_id              (package_id)
#  user_id                 (user_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (user_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
