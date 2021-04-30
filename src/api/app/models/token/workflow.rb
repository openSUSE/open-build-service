class Token::Workflow < Token
  def self.token_name
    'workflow'
  end

  def call(options)
    payload = options[:payload]
    scm = options[:scm] # github, gitlab
    event = options[:event] # pull_request, merge_request

    extractor = TriggerControllerService::ScmExtractor.new(scm, event, payload)

    return unless extractor.accepted_event_and_action?

    # scm_extractor_payload = extractor.call # returns { scm: 'github', repo_url: 'http://...' }
    # yaml_file = Workflows::YAMLDownloadService.new(scm_extractor_payload).call
    # workflows = Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, pr_number: scm_extractor_payload[:pr_number]).call
    # step = workflows.first.steps.first
    # step.call if step.valid?

    # Read configuration file
    #   if the ref is not included in the config file's branch whitelist we do nothing.

    # Decide what to do by action:
    # FIXME: Who does this branching? Should we just overwrite the _service file with the data coming
    #        from the workflow config file and trigger a Service token?
    # - opened -> create a branch package on OBS using the configuration file's details and the PR number.
    # - synchronize -> get the existent branched package on OBS and ensure it updates the source
    #                  code and it rebuilds (trigger service). We should have a previous branch with the
    #                  contents of the initial pull_request or the previous synchronization.
    # - closed -> remove the existent branched package

    # Some pseudocode:
    # if scm_extractor_payload.scm == 'github' && scm_extractor_payload.action == 'opened'
    # end

    # if scm_extractor_payload.scm == 'gitlab' && scm_extractor_payload.action == 'open'
    # end

    ['Event::BuildFail', 'Event::BuildSuccess'].each do |build_event|
      EventSubscription.create!(eventtype: build_event,
                                receiver_role: 'watcher', # TODO: check if this makes sense
                                user: user,
                                channel: 'scm',
                                enabled: true,
                                token: self,
                                payload: payload)
    end

    SCMStatusReporter.new(scm_extractor_payload, scm_token).call
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
