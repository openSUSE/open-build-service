# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateProjectLogEntryJob, type: :job do
  describe '#perform' do
    let!(:user1) { create(:confirmed_user) }
    let!(:user2) { create(:confirmed_user) }
    let!(:project) { create(:project) }

    before do
      10.times do
        Event::CommentForProject.create(
          project: project.name,
          commenters: [user1.id, user2.id],
          commenter: user2.id,
          comment_body: "Hey #{user1.login}, how are you?"
        )
      end
    end

    it 'creates a ProjectLogEntry' do
      expect(ProjectLogEntry.count).to eq(10)
    end
  end
end
