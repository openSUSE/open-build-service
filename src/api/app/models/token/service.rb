class Token::Service < Token
  def call(options)
    set_triggered_at
    Backend::Api::Sources::Package.trigger_services(options[:project].to_param,
                                                    options[:package].to_param,
                                                    executor.login)
  end

  def package_find_options
    { follow_project_links: false }
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id                          :integer          not null, primary key
#  description                 :string(64)       default("")
#  enabled                     :boolean          default(TRUE), not null, indexed
#  scm_token                   :string(255)      indexed
#  string                      :string(255)      indexed
#  triggered_at                :datetime
#  type                        :string(255)
#  workflow_configuration_path :string(255)      default(".obs/workflows.yml")
#  workflow_configuration_url  :string(8192)
#  executor_id                 :integer          not null, indexed
#  package_id                  :integer          indexed
#
# Indexes
#
#  index_tokens_on_enabled    (enabled)
#  index_tokens_on_scm_token  (scm_token)
#  index_tokens_on_string     (string) UNIQUE
#  package_id                 (package_id)
#  user_id                    (executor_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (executor_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
