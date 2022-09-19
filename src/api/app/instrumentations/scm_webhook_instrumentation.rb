module SCMWebhookInstrumentation
  extend ActiveSupport::Concern

  # Define callbacks with ActiveModel::Callback which is included in ActiveModel::Model
  included do
    define_model_callbacks :initialize

    after_initialize :track_webhook
  end

  private

  def track_webhook
    RabbitmqBus.send_to_bus('metrics', "scm_webhook,scm=#{@payload[:scm]},webhook_event=#{webhook_event} count=1")
  end

  def webhook_event
    case
    when push_event?
      'push'
    when tag_push_event?
      'tag_push'
    when pull_request_event?
      'pull_request'
    else
      'unsupported'
    end
  end
end
