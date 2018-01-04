require 'rails_helper'

RSpec.describe Notification do
  let(:payload) { { comment: 'SuperFakeComment', requestid: 1 } }
  let(:delete_package_event) { Event::DeletePackage.new(payload) }

  describe '#event' do
    subject { create(:rss_notification, event_type: 'Event::DeletePackage', event_payload: payload).event }

    it { expect(subject.class).to eq(delete_package_event.class) }
    it { expect(subject.payload).to eq(delete_package_event.payload) }
  end

  describe 'payload is shortened' do
    let(:user) { create(:confirmed_user, id: 1, login: 'tom') }
    let(:comment_author) { create(:confirmed_user, id: 2, login: 'jerry') }
    let(:event) do
      Event::CommentForProject.new(
        project: user.home_project_name,
        commenters: [comment_author.id, user.id],
        commenter: comment_author.id,
        comment_body: comment_body
      )
    end
    let(:serialised_payload) { ActiveSupport::JSON.encode(subject.event_payload) }
    let(:serialised_comment_body) { ActiveSupport::JSON.encode(subject.event_payload['comment_body']) }

    subject { create(:rss_notification, event_type: event.class, event_payload: event.payload) }

    context 'with the payload small enough to fit into the payload column' do
      let(:comment_body) { '<a>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' }

      it { expect(serialised_payload.bytesize).to eq(119) }
      # Serializing the payload expands special chars to hexadecimal format
      it { expect(serialised_comment_body).to eq('"\u003ca\u003eaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"') }
      it { expect(serialised_comment_body.bytesize).to eq(48) }
    end

    context 'with the comment body too long for the payload column' do
      # The events.payload column has a max char limit of 65535 so this comment cannot fit
      # in the payload unless it is shortened
      let(:comment_body) { '<a>' + 'a' * 65532 }

      it { expect(serialised_payload.bytesize).to eq(65535) }
      # Serializing the payload expands special chars to hexadecimal format
      it { expect(serialised_comment_body).to eq('"\u003ca\u003e' + ('a' * 65449) + '"') }
      # The comment body is shortened to acommodate the payload length into the column
      it { expect(serialised_comment_body.bytesize).to eq(65464) }
    end
  end
end
