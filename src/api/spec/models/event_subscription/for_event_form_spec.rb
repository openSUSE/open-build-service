RSpec.describe EventSubscription::ForEventForm do
  include_context 'a user and subscriptions'

  let(:subscriber) { user }

  describe '#call' do
    subject { EventSubscription::ForEventForm.new(event_class, subscriber).call }

    let(:roles) { subject.roles }

    context 'for Event::CommentForProject' do
      let(:event_class) { Event::CommentForProject }
      let(:expected_receiver_roles) do
        %i[bugowner commenter maintainer project_watcher]
      end

      it { expect(subject.event_class).to eq(event_class) }
      it { expect(roles.map(&:name)).to match_array(expected_receiver_roles) }
    end

    context 'for Event::CommentForRequest' do
      let(:event_class) { Event::CommentForRequest }
      let(:expected_receiver_roles) do
        %i[commenter creator request_watcher reviewer source_maintainer source_package_watcher source_project_watcher target_maintainer target_package_watcher target_project_watcher]
      end

      it { expect(subject.event_class).to eq(event_class) }
      it { expect(roles.map(&:name)).to match_array(expected_receiver_roles) }
    end
  end
end
