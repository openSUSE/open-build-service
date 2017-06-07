require 'rails_helper'

RSpec.describe CleanupEvents, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:user) { create(:confirmed_user, digest_email_enabled: true) }
    let!(:subscription1) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: user) }

    let!(:event1) { Event::Base.create(eventtype: 'Event::CommentForProject') }
    let!(:event2) { Event::Base.create(eventtype: 'Event::CommentForProject') }
    let!(:event3) { Event::Base.create(eventtype: 'Event::CommentForProject') }

    before do
      # Do this here becuase Event::Base overrides ActiveRecord::Base.initialize which means we can't set these attrs on create
      event1.update_attributes!(project_logged: true, queued: true, undone_jobs: 0)
      event2.update_attributes!(project_logged: true, queued: true, undone_jobs: 0)
      event3.update_attributes!(project_logged: true, queued: true, undone_jobs: 0)
    end

    let!(:digest_email1) { create(:digest_email, event_subscription: subscription1, events: [event1], email_sent: false) }
    let!(:digest_email2) { create(:digest_email, event_subscription: subscription1, events: [event1], email_sent: true) }

    let!(:digest_email3) { create(:digest_email, event_subscription: subscription1, events: [event2], email_sent: true) }
    let!(:digest_email4) { create(:digest_email, event_subscription: subscription1, events: [event2], email_sent: true) }

    subject! { CleanupEvents.new.perform }

    it 'keeps the event which has at least one unsent digest_email' do
      expect(Event::Base.exists?(id: event1.id)).to be_truthy
    end

    it 'deletes the event which has all of its digest_emails sent' do
      expect(Event::Base.exists?(id: event2.id)).to be_falsey
    end

    it 'deletes the event which has no digest_emails' do
      expect(Event::Base.exists?(id: event3.id)).to be_falsey
    end
  end
end
