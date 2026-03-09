RSpec.describe BsRequestCommentComponent, type: :component do
  let(:commentable) { create(:bs_request_with_submit_action) }
  let(:comment_a) { travel_to(1.day.ago) { create(:comment_request, commentable: commentable, body: 'Comment A') } }

  before do
    render_inline(described_class.new(comment: comment_a, commentable: commentable, level: 1))
  end

  it 'displays a comment icon' do
    expect(rendered_content).to have_css('i.fa-comment', count: 1)
  end

  it 'displays an avatar' do
    expect(rendered_content).to have_css("img[title='#{comment_a.user.realname}']", count: 1)
  end

  it 'displays who wrote the comment' do
    expect(rendered_content).to have_text("#{comment_a.user.realname} (#{comment_a.user.login})\ncommented")
  end

  it 'displays the time when the comment happened in words' do
    expect(rendered_content).to have_text('1 day ago')
  end

  it 'displays the comment' do
    expect(rendered_content).to have_text('Comment A')
  end

  context 'when the user is not logged in' do
    it 'is not possible to reply a comment' do
      expect(rendered_content).to have_no_text('Reply')
    end
  end

  context 'when the user is logged in and is the author of the comment' do
    before do
      User.session = comment_a.user
      render_inline(described_class.new(comment: comment_a, commentable: commentable, level: 1))
    end

    it 'is possible to reply to the comment' do
      expect(rendered_content).to have_text('Reply')
    end

    it 'is possible to edit the comment' do
      expect(rendered_content).to have_css('.dropdown-menu', text: 'Edit')
    end

    it 'is possible to remove the comment' do
      expect(rendered_content).to have_css('.dropdown-menu', text: 'Delete')
    end
  end

  context 'when the user is logged in but is not the author of the comment' do
    before do
      User.session = build(:confirmed_user)
      render_inline(described_class.new(comment: comment_a, commentable: commentable, level: 1))
    end

    it 'is possible to reply to the comment' do
      expect(rendered_content).to have_text('Reply')
    end

    it 'is not possible to edit the comment' do
      expect(rendered_content).to have_no_css('.dropdown-menu', text: 'Edit')
    end

    it 'is not possible to remove the comment' do
      expect(rendered_content).to have_no_css('.dropdown-menu', text: 'Delete')
    end
  end

  context 'when rendering a comment thread' do
    let!(:comment_b) { create(:comment_request, commentable: commentable, body: 'Comment B', parent: comment_a) } # level 1 => 2 nested .timeline-item-comment
    let(:comment_c) { create(:comment_request, commentable: commentable, body: 'Comment C', parent: comment_b) }
    let(:comment_d) { create(:comment_request, commentable: commentable, body: 'Comment D', parent: comment_c) }
    let!(:comment_e) { create(:comment_request, commentable: commentable, body: 'Comment E', parent: comment_d) }

    before do
      render_inline(described_class.new(comment: comment_a, commentable: commentable, level: 1))
    end

    it 'displays the parent comment' do
      expect(rendered_content).to have_text("(#{comment_a.user.login})\ncommented")
      expect(rendered_content).to have_text('Comment A')
    end

    it 'displays the third child comment on the third children level' do
      expect(rendered_content).to have_css("#{(['.d-flex > .timeline-item-comment'] * 4).join(' > ')} > .comment-bubble", text: "(#{comment_d.user.login})\ncommented")
      expect(rendered_content).to have_css("#{(['.d-flex > .timeline-item-comment'] * 4).join(' > ')} > .comment-bubble", text: 'Comment D')
    end

    it 'does not display the fourth child comment on the fourth children level' do
      expect(rendered_content).to have_no_css("#{(['.d-flex > .timeline-item-comment'] * 5).join(' > ')} > .comment-bubble", text: 'Comment E')
    end

    it 'does not display the fourth child comment on the third children level' do
      expect(rendered_content).to have_css("#{(['.d-flex > .timeline-item-comment'] * 4).join(' > ')} > .comment-bubble", text: 'Comment E')
    end
  end

  describe '#range' do
    context "when the file is new (no 'old' diff present)" do
      let(:added_diff) do
        {
          'state' => 'added',
          'new' => {
            'size' => '340'
          },
          'diff' => {
            'lines' => '12',
            '_content' => "@@ -0,0 +1,11 @@\n+--\n+Fri Aug 11 \n+\n+- Testing the submit diff\n+- Fixing issue among others.\n+\n+--\n+Wed Aug  2 14:59:15 UTC 2017\n+\n+- Temporary hack\n+\n"
          }
        }
      end

      it 'returns a single-line range for the commented line' do
        comment_a.update(diff_line_number: 6)
        component = described_class.new(comment: comment_a, commentable: commentable, level: 1, diff: added_diff)

        expect(component.range).to eq(5..5)
      end
    end

    context 'when the file is modified' do
      let(:changed_diff) do
        {
          'state' => 'changed',
          'old' => { 'name' => 'somefile.txt', 'md5' => '6741a2f4... ', 'size' => '74' },
          'new' => { 'name' => 'somefile.txt', 'md5' => '801c9f97... ', 'size' => '65' },
          'diff' => {
            'lines' => '5',
            '_content' => "@@ -1,1 +1,1 @@\n-Minima tenetlabore.\n\\ No newline at end of file\n+Impedit dolores recusandae.\n\\ No newline at end of file\n"
          }
        }
      end

      it 'returns a range starting from the removed line when commenting on the added line' do
        comment_a.update(diff_line_number: 4)
        component = described_class.new(comment: comment_a, commentable: commentable, level: 1, diff: changed_diff)

        expect(component.range).to eq(1..3)
      end
    end
  end
end
