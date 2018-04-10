# frozen_string_literal: true
class EventSubscription
  class Form
    attr_reader :subscriber

    def initialize(subscriber = nil)
      @subscriber = subscriber
    end

    def subscriptions_by_event
      GenerateHashForSubscriber.new(subscriber).query
    end

    def update!(subscriptions_params)
      subscriptions_params.each do |_i, subscription_params|
        subscription = find_or_initialize_subscription(
          subscription_params[:eventtype],
          subscription_params[:receiver_role]
        )
        subscription.channel = subscription_params[:channel]
        subscription.save!
      end
    end

    private

    def find_or_initialize_subscription(eventtype, receiver_role)
      opts = { eventtype: eventtype, receiver_role: receiver_role }

      if subscriber.is_a? User
        opts[:user] = subscriber
      elsif subscriber.is_a? Group
        opts[:group] = subscriber
      elsif subscriber.nil?
        opts[:user] = nil
        opts[:group] = nil
      end

      EventSubscription.find_or_initialize_by(opts)
    end
  end
end
