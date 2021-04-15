class Token::Service < Token
  def self.token_name
    'runservice'
  end

  def code_from_webhook_controller
    if !@user.is_active? || !@user.can_modify?(@package)
      render_error message: 'Token not found or not valid.', status: 404
      return
    end

    Backend::Api::Sources::Package.trigger_services(@package.project.name, @package.name, @user.login)
    render_ok
  end

  def runservice
    raise NoPermissionForPackage.setup('no_permission', 403, "no permission for package #{@pkg} in project #{@pkg.project}") unless policy(@pkg).update?

    # execute the service in backend
    pass_to_backend(prepare_path_for_runservice)

    @pkg.sources_changed
  end

  private

  def prepare_path_for_runservice
    path = @pkg.source_path
    params = { cmd: 'runservice', comment: 'runservice via trigger', user: User.session!.login }
    URI(path + build_query_from_hash(params, [:cmd, :comment, :user])).to_s
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
