class Token::Rebuild < Token
  def self.token_name
    'rebuild'
  end

  def call(options)
    package_name = options[:package].to_param
    package_name += ':' + options[:multibuild_flavor] if options[:multibuild_flavor]
    Backend::Api::Sources::Package.rebuild(options[:project].to_param,
                                           package_name,
                                           options.slice(:repository, :arch).compact)
  end

  def package_find_options
    { use_source: false, follow_project_links: true, follow_multibuild: true }
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
