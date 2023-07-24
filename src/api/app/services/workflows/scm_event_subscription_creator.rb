module Workflows
  class ScmEventSubscriptionCreator
    def initialize(token, workflow_run, scm_webhook, package)
      @token = token
      @workflow_run = workflow_run
      @scm_webhook = scm_webhook
      @package = package
    end

    def call
      ['Event::BuildFail', 'Event::BuildSuccess'].each do |build_event|
        EventSubscription.find_or_create_by!(eventtype: build_event,
                                             # We pass a valid value, but we don't need this.
                                             receiver_role: 'reader',
                                             user: @token.executor,
                                             channel: 'scm',
                                             enabled: true,
                                             token: @token,
                                             package: @package).tap do |subscription|
          # Set payload and workflow_run regardless of whether the subscription already existed or not
          subscription.update!(workflow_run: @workflow_run, payload: @scm_webhook.payload)
        end
      end
    end
  end
end
