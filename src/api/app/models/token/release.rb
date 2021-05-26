class Token::Release < Token
  include MaintenanceHelper

  def self.token_name
    'release'
  end

  def call(options)
    return unless options[:package]

    # FIXME: Take repository and arch into account
    package_to_release = options[:package]
    manual_release_targets = package_to_release.project.release_targets.where(trigger: 'manual')
    raise NoReleaseTargetFound, "#{package_to_release.project} has no release targets that are triggered manually" unless manual_release_targets.any?

    manual_release_targets.each do |release_target|
      opts = { filter_source_repository: release_target.repository,
               manual: true,
               comment: 'Releasing via trigger event' }
      opts[:multibuild_container] = options[:multibuild_flavor] if options[:multibuild_flavor].present?
      release_package(package_to_release,
                      release_target.target_repository,
                      package_to_release.release_target_name,
                      opts)
    end
  end

  def package_find_options
    { use_source: true, follow_project_links: false, follow_multibuild: true }
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id         :integer          not null, primary key
#  scm_token  :string(255)      indexed
#  string     :string(255)      indexed
#  type       :string(255)
#  package_id :integer          indexed
#  user_id    :integer          not null, indexed
#
# Indexes
#
#  index_tokens_on_scm_token  (scm_token)
#  index_tokens_on_string     (string) UNIQUE
#  package_id                 (package_id)
#  user_id                    (user_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (user_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
