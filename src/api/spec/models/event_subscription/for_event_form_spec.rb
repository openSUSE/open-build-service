require 'rails_helper'

RSpec.describe EventSubscription::ForEventForm do
  include_context 'a user and subscriptions'

  let(:subscriber) { user }

  describe '#call' do
    let(:roles) { subject.roles }
    # TODO: Remove this after all event subscriptions are migrated to the new receiver role name `project_watcher`
    let(:deprecated_roles) { [:watcher, :source_watcher, :target_watcher] }

    subject { EventSubscription::ForEventForm.new(event_class, subscriber).call }

    context 'for Event::CommentForProject' do
      let(:event_class) { Event::CommentForProject }
      let(:expected_receiver_roles) do
        event_class.receiver_roles - deprecated_roles
      end

      it { expect(subject.event_class).to eq(event_class) }
      it { expect(roles.map(&:name)).to match_array(expected_receiver_roles) }
    end

    context 'for Event::CommentForRequest' do
      let(:event_class) { Event::CommentForRequest }
      let(:expected_receiver_roles) do
        event_class.receiver_roles - deprecated_roles
      end

      it { expect(subject.event_class).to eq(event_class) }
      it { expect(roles.map(&:name)).to match_array(expected_receiver_roles) }
    end
  end
end
