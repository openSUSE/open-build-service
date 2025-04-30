module Workflows
  class ScmEventSubscriptionCreator
    def initialize(token, workflow_run, package_or_request)
      @token = token
      @workflow_run = workflow_run
      @package_or_request = package_or_request
    end

    def call
      # SCMs don't support commit status for tags, so we don't need to report back in this case
      return if @workflow_run.tag_push_event?

      create_or_update_subscriptions_for_package(package: @package_or_request) if @package_or_request.is_a?(Package)
      create_or_update_subscriptions_for_request(bs_request: @package_or_request) if @package_or_request.is_a?(BsRequest)
    end

    private

    def create_or_update_subscriptions_for_package(package:)
      ['Event::BuildFail', 'Event::BuildSuccess'].each do |build_event|
        EventSubscription.find_or_create_by!(eventtype: build_event,
                                             # We pass a valid value, but we don't need this.
                                             receiver_role: 'reader',
                                             user: @token.executor,
                                             channel: 'scm',
                                             enabled: true,
                                             token: @token,
                                             package: package).tap do |subscription|
          # Set payload and workflow_run regardless of whether the subscription already existed or not
          subscription.update!(workflow_run: @workflow_run, payload: @workflow_run.payload)
        end
      end
    end

    def create_or_update_subscriptions_for_request(bs_request:)
      EventSubscription.find_or_create_by!(eventtype: 'Event::RequestStatechange',
                                           receiver_role: 'reader', # We pass a valid value, but we don't need this.
                                           user: @token.executor,
                                           channel: 'scm',
                                           enabled: true,
                                           token: @token,
                                           bs_request: bs_request).tap do |subscription|
        subscription.update!(workflow_run: @workflow_run, payload: @workflow_run.payload) # The payload is updated regardless of whether the subscription already existed or not.
      end
    end
  end
end
