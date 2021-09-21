class Token::Workflow < Token
  validates :scm_token, presence: true

  def self.token_name
    'workflow'
  end

  def call(options)
    raise ArgumentError, 'A payload is required' if options[:payload].nil?

    scm_webhook = TriggerControllerService::ScmExtractor.new(options[:scm], options[:event], options[:payload]).call
    return unless scm_webhook.valid?

    yaml_file = Workflows::YAMLDownloader.new(scm_webhook.payload, token: self).call
    workflows = Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, scm_webhook: scm_webhook, token: self).call
    workflows.each(&:call)
  rescue Octokit::Unauthorized, Gitlab::Error::Unauthorized => e
    raise Token::Errors::SCMTokenInvalid, e.message
  end

  # Only used by rebuild steps
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
