class Token::Service < Token
  def self.token_name
    'runservice'
  end

  def call(_options)
    # we can not work on remote sources
    raise ActiveRecord::RecordNotFound if package_from_association_or_params.nil?
    Backend::Api::Sources::Package.trigger_services(package_from_association_or_params.project.name,
                                                    package_from_association_or_params.name,
                                                    user.login)
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
