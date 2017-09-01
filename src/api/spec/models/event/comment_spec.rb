require 'rails_helper'

RSpec.describe Event::CommentForProject do
  describe '.shorten_payload_if_necessary' do
    context 'with the comment body too long for the payload column' do
      let!(:project) { create(:project) }
      let!(:user) { create(:confirmed_user) }
      let!(:comment_author) { create(:confirmed_user) }

      # The events.payload column has a max char limit of 65,535 so this comment cannot fit
      # in the payload unless it is shortened
      let(:comment_body) { Faker::Lorem.characters(65535) }
      let(:event) do
        Event::CommentForProject.new(
          project: project.name,
          commenters: [comment_author.id, user.id],
          commenter: comment_author.id,
          comment_body: comment_body
        )
      end

      subject! { event.save }

      it 'creates the event with a shortened payload' do
        expect(event).to be_persisted
      end

      it 'shortens the payload to fit in the database' do
        raw_payload = event.attributes_before_type_cast['payload']
        expect(raw_payload.length).to be <= 65535
      end
    end
  end
end
