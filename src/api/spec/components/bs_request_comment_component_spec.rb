require 'rails_helper'

RSpec.describe BsRequestCommentComponent, type: :component do
  let(:commentable) { create(:bs_request_with_submit_action) }
  let(:comment_a) { create(:comment_request, commentable: commentable, body: 'Comment A') }

  subject { render_inline(described_class.new(comment: comment_a, commentable: commentable, level: 1)) }

  context 'when the user is not logged in' do
    it 'is not possible to reply a comment' do
      expect(subject).not_to have_text('Reply')
    end
  end

  context 'when the user is logged in and is the author of the comment' do
    before do
      User.session = comment_a.user
    end

    it 'is possible to reply to the comment' do
      expect(subject).to have_text('Reply')
    end

    it 'is possible to edit the comment' do
      expect(subject).to have_selector('.dropdown-menu', text: 'Edit')
    end

    it 'is possible to remove the comment' do
      expect(subject).to have_selector('.dropdown-menu', text: 'Delete')
    end
  end

  context 'when the user is logged in but is not the author of the comment' do
    before do
      User.session = build(:confirmed_user)
    end

    it 'is possible to reply to the comment' do
      expect(subject).to have_text('Reply')
    end

    it 'is not possible to edit the comment' do
      expect(subject).not_to have_selector('.dropdown-menu', text: 'Edit')
    end

    it 'is not possible to remove the comment' do
      expect(subject).not_to have_selector('.dropdown-menu', text: 'Delete')
    end
  end

  context 'when rendering a comment thread' do
    let(:comment_b) { create(:comment_request, commentable: commentable, body: 'Comment B', parent: comment_a) }
    let!(:comment_c) { create(:comment_request, commentable: commentable, body: 'Comment C', parent: comment_b) }
    let(:comment_d) { create(:comment_request, commentable: commentable, body: 'Comment D', parent: comment_c) }
    let!(:comment_e) { create(:comment_request, commentable: commentable, body: 'Comment E', parent: comment_d) }

    it 'displays the parent comment' do
      expect(subject).to have_text("(#{comment_a.user.login})\nwrote")
      expect(subject).to have_text('Comment A')
    end

    it 'displays the comments on level 2 in the 2nd level' do
      expect(subject).to have_selector('.timeline-item-comment > .timeline-item-comment', text: "(#{comment_c.user.login})\nwrote")
      expect(subject).to have_selector('.timeline-item-comment > .timeline-item-comment  > .timeline-item-comment', text: 'Comment C')
    end

    it 'does not display the comments on level 4 in the 4th one' do
      expect(subject).not_to have_selector((['.timeline-item-comment'] * 4).join(' > '), text: "(#{comment_e.user.login})\nwrote")
      expect(subject).not_to have_selector((['.timeline-item-comment'] * 5).join(' > '), text: "(#{comment_e.user.login})\nwrote")
    end

    it 'displays the comments on level 4 in the 3rd level' do
      expect(subject).to have_selector((['.timeline-item-comment'] * 3).join(' > '), text: "(#{comment_e.user.login})\nwrote")
      expect(subject).to have_selector((['.timeline-item-comment'] * 4).join(' > '), text: 'Comment E')
    end
  end
end
