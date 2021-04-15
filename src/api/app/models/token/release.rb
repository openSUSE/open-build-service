class Token::Release < Token
  def self.token_name
    'release'
  end

  def release
    raise NoPermissionForPackage.setup('no_permission', 403, "no permission for package #{@pkg} in project #{@pkg.project}") unless policy(@pkg).update?

    manual_release_targets = @pkg.project.release_targets.where(trigger: 'manual')
    raise NoPermissionForPackage.setup('not_found', 404, "#{@pkg.project} has no release targets that are triggered manually") unless manual_release_targets.any?

    manual_release_targets.each do |release_target|
      release_package(@pkg,
                      release_target.target_repository,
                      @pkg.release_target_name,
                      { filter_source_repository: release_target.repository,
                        manual: true,
                        comment: 'Releasing via trigger event' })
    end

    render_ok
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
