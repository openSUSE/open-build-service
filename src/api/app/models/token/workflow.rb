class Token::Workflow < Token
  validates :scm_token, presence: true

  def self.token_name
    'workflow'
  end

  def call(options)
    extractor = TriggerControllerService::ScmExtractor.new(options[:scm], options[:event], options[:payload])
    return unless extractor.allowed_event_and_action?

    scm_extractor_payload = extractor.call
    yaml_file = Workflows::YAMLDownloader.new(scm_extractor_payload, token: self).call
    workflows = Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, scm_extractor_payload: scm_extractor_payload, token: self).call
    workflows.each do |workflow|
      workflow.steps.each do |step|
        run_step_and_report(step, scm_extractor_payload, scm_token)
      end
    end
  rescue Octokit::Unauthorized, Gitlab::Error::Unauthorized => e
    raise Token::Errors::SCMTokenInvalid, e.message
  end

  private

  def run_step_and_report(step, scm_extractor_payload, scm_token)
    package_from_step = step.call
    step.set_subscription(package_from_step, scm_extractor_payload, user, self)
    step.report!(scm_extractor_payload, scm_token)
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
