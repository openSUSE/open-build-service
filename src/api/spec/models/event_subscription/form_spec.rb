# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EventSubscription::Form do
  describe '#update!' do
    include_context 'a user and subscriptions with defaults'

    context 'with a user as the subscriber' do
      subject! { EventSubscription::Form.new(user).update!(subscription_params) }

      it_behaves_like 'a subscriptions form for subscriber'
    end

    context 'with nil as the subscriber (default)' do
      subject! { EventSubscription::Form.new(nil).update!(subscription_params) }

      it_behaves_like 'a subscriptions form for default'
    end
  end
end
