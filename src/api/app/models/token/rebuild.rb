class Token::Rebuild < Token
  def self.token_name
    'rebuild'
  end

  # TODO: Use package_from_association_or_params instead of package
  # def call(package:, project:, repository:, architecture:) USE THIS
  def call(options)
    # TODO: Use the Package#rebuild? instead of calling the Backend directly
    Backend::Api::Sources::Package.rebuild(package_from_association_or_params.project.name,
                                           package_from_association_or_params.name)
  end

  def package_find_options
    { use_source: false, follow_project_links: true, follow_multibuild: true }
  end
end

#### TODO: keep it or delete
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
