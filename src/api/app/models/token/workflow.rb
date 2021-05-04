class Token::Workflow < Token
  def self.token_name
    'workflow'
  end

  def call(options)
    extractor = TriggerControllerService::ScmExtractor.new(options[:scm], options[:event], options[:payload])
    return unless extractor.allowed_event_and_action?

    scm_extractor_payload = extractor.call # returns { scm: 'github', repo_url: 'http://...' }
    yaml_file = Workflows::YAMLDownloader.new(scm_extractor_payload).call
    workflows = Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, scm_extractor_payload: scm_extractor_payload).call
    step = workflows.first.steps.first
    package_from_step = if step && step.valid?
                          step.call
                        else
                          # TODO: Raise a proper error
                          raise 'Something something'
                        end

    ['Event::BuildFail', 'Event::BuildSuccess'].each do |build_event|
      # TODO: Deal with old EventSubscription (this can happen when someone pushes a new commit to a PR/branch, then we only want to report to the latest commit)
      EventSubscription.create!(eventtype: build_event,
                                receiver_role: 'reader', # We pass a valid value, but we don't need this.
                                user: user,
                                channel: 'scm',
                                enabled: true,
                                token: self,
                                package: package_from_step,
                                payload: scm_extractor_payload)
    end

    SCMStatusReporter.new(scm_extractor_payload, scm_token).call
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
