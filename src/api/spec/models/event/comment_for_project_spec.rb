RSpec.describe Event::CommentForProject do
  describe 'payload is shortened' do
    subject! { event.save }

    let(:project) { create(:project) }
    let(:user) { create(:confirmed_user) }
    let(:comment_author) { create(:confirmed_user) }
    let(:event) do
      Event::CommentForProject.new(
        project: project.name,
        commenters: [comment_author.id, user.id],
        commenter: comment_author.id,
        comment_body: comment_body
      )
    end

    context 'with the payload small enough to fit into the payload column' do
      let(:comment_body) { Faker::Lorem.characters(number: 50) }

      it { expect(event).to be_persisted }
      it { expect(event.payload['comment_body'].bytesize).to eq(50) }
    end

    context 'with the comment body too long for the payload column' do
      # The events.payload column has a max char limit of 65535 so this comment cannot fit
      # in the payload unless it is shortened
      let(:comment_body) { Faker::Lorem.characters(number: 65_535) }
      let(:event) do
        Event::CommentForProject.new(
          project: project.name,
          commenters: [comment_author.id, user.id],
          commenter: comment_author.id,
          comment_body: comment_body
        )
      end

      it { expect(event).to be_persisted }

      it 'shortens the payload to fit in the database' do
        raw_payload = event.attributes_before_type_cast['payload']
        expect(raw_payload.length).to be <= 65_535
      end
    end
  end
end
