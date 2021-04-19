class Token::Rebuild < Token
  def self.token_name
    'rebuild'
  end

  def call(params)
    package_name = package&.name || params[:package]
    project_name = package&.project.name || params[:project]

    Backend::Api::Sources::Package.rebuild(project_name, package_name, params)
  end

  # authorization needs to check:
  # sourceaccess => package.check_source_access?
  # follow_multibuild => already handled by backend (packages names with '*:' in the name)

  opts = if @token.instance_of?(Token::Rebuild)
    { use_source: false,
      follow_project_links: true,
      follow_multibuild: true }
  else
    { use_source: true,
      follow_project_links: false,
      follow_multibuild: false }
  end

  @pkg = Package.get_by_project_and_name(params[:project].to_s, params[:package].to_s, opts)

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
