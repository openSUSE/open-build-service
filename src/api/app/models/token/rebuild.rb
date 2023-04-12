class Token::Rebuild < Token
  def call(options)
    set_triggered_at
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
#  id                          :integer          not null, primary key
#  description                 :string(64)       default("")
#  scm_token                   :string(255)      indexed
#  string                      :string(255)      indexed
#  triggered_at                :datetime
#  type                        :string(255)
#  workflow_configuration_path :string(255)      default(".obs/workflows.yml")
#  workflow_configuration_url  :string(255)
#  executor_id                 :integer          not null, indexed, indexed
#  package_id                  :integer          indexed, indexed
#
# Indexes
#
#  index_tokens_executor_id   (executor_id) UNIQUE
#  index_tokens_on_scm_token  (scm_token)
#  index_tokens_on_string     (string) UNIQUE
#  index_tokens_package_id    (package_id) UNIQUE
#  package_id                 (package_id)
#  user_id                    (executor_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (executor_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
