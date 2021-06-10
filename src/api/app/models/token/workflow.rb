class Token::Workflow < Token
  def self.token_name
    'workflow'
  end

  def call(options)
    extractor = TriggerControllerService::ScmExtractor.new(options[:scm], options[:event], options[:payload])
    return unless extractor.allowed_event_and_action?

    scm_extractor_payload = extractor.call
    yaml_file = Workflows::YAMLDownloader.new(scm_extractor_payload).call
    workflows = Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, scm_extractor_payload: scm_extractor_payload, token: self).call

    workflows.each do |workflow|
      workflow.steps.each do |step|
        run_step_and_report(step, scm_extractor_payload, scm_token)
      end
    end
  end

  private

  def run_step_and_report(step, scm_extractor_payload, scm_token)
    raise 'Invalid workflow step definition' unless step.valid?

    package_from_step = step.call

    raise "We couldn't branch your package" unless package_from_step

    set_subscription(package_from_step, scm_extractor_payload)

    Project.get_by_name(step.target_project).repositories.each do |repository|
      # TODO: Fix n+1 queries
      repository.architectures.each do |architecture|
        # We cannot report multibuild flavors here... so they will be missing from the initial report
        SCMStatusReporter.new({ project: step.target_project, package: step.target_package, repository: repository.name, arch: architecture.name },
                              scm_extractor_payload, scm_token).call
      end
    end
  end

  def set_subscription(package_from_step, scm_extractor_payload)
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
