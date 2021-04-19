class Token::Rebuild < Token
  def self.token_name
    'rebuild'
  end

  def call(params)
    package_name = package&.name || params[:package]
    project_name = package&.project.name || params[:project]

    Backend::Api::Sources::Package.rebuild(project_name, package_name, params)
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
