class Token::Service < Token
  def self.token_name
    'runservice'
  end

  # TODO: Use package_from_association_or_params instead of package
  def call(_params)
    Backend::Api::Sources::Package.trigger_services(package.project.name, package.name, user.login)
    # TODO
    # check if its necessary
    package.sources_changed
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
