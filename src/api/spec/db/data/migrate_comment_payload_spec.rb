require Rails.root.join('db/data/20190228170655_migrate_comment_payload.rb')

RSpec.describe MigrateCommentPayload do
  describe '.up' do
    let!(:comment_for_package) { create(:comment_package) }
    let!(:comment_for_project) { create(:comment_project) }
    let!(:comment_for_request) { create(:comment_request) }
    let(:commenter) { create(:user) }
    let(:commenters) { create_list(:user, 3) }

    def comment_event?(event)
      event.class.in?([Event::CommentForPackage, Event::CommentForProject, Event::CommentForRequest])
    end

    before do
      # Create events in the old format
      Event::Base.find_each do |event|
        next unless comment_event?(event)

        payload = event.payload
        payload['commenter'] = commenter.id
        payload['commenters'] = commenters.pluck(:id)
        event.set_payload(payload, payload.keys)
        event.save!
      end

      subject.up
    end

    it 'converts comment events in the old format' do
      Event::Base.find_each do |event|
        next unless comment_event?(event)

        expect(event.payload['commenter']).to eq(commenter.login)
        expect(event.payload['commenters']).to eq(commenters.pluck(:login))
      end
    end
  end
end
