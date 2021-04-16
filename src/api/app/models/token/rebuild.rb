class Token::Rebuild < Token
  def self.token_name
    'rebuild'
  end

  def rebuild
    rebuild_trigger = PackageControllerService::RebuildTrigger.new(package: package, project: package.project, params: params)
    #authorize rebuild_trigger.policy_object, :update?
    rebuild_trigger.rebuild?
    #render_ok
  end

  def package(project_name, package_name)
    opts = { use_source: false,
             follow_project_links: true,
             follow_multibuild: true }
    package || Package.get_by_project_and_name(project_name, package_name, opts)
  end
end

####
#
#
# id     user   package
#
# 123456 Admin  nil
# 123457 Admin  home:Admin:test
#
# /trigger/rebuild?token=123456 # This won't work.
#
# /trigger/rebuild?token=123456&project=home:Admin&package=test&repository=openSUSE_Tumbleweed&arch=x86_64
#
# /trigger/rebuild?token=123457 # This will work.
#
# /trigger/rebuild?token=123457&project=IGNORED&package=IGNORED&repository=openSUSE_Tumbleweed&arch=x86_64
#
####

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
