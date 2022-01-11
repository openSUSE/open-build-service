require 'rails_helper'

RSpec.describe CommentComponent, type: :component do
  let(:builder) { Builder::XmlMarkup.new }

  before do
    render_inline(described_class.new(comment: comment, obj_is_user: true, builder: builder))
  end

  shared_examples 'rendering the body, who, when and the id' do
    it "renders the comment's body" do
      expect(builder).to have_text(comment.body)
    end

    it "renders who commented as an attribute of the comment's tag" do
      expect(builder).to have_xpath("//comment_[contains(@who, '#{comment.user.login}')]")
    end

    it "renders when the comment was commented as an attribute of the comment's tag" do
      expect(builder).to have_xpath("//comment_[contains(@when, '#{comment.created_at}')]")
    end

    it 'renders the id of the comment' do
      expect(builder).to have_xpath("//comment_[contains(@id, '#{comment.id}')]")
    end
  end

  context 'when the comment has a user, the comment creation date' do
    context 'and the commentable is a Project' do
      let(:comment) { create(:comment_project) }

      it_behaves_like 'rendering the body, who, when and the id'

      it 'renders the project of the comment' do
        expect(builder).to have_xpath("//comment_[contains(@project, '#{comment.commentable.name}')]")
      end
    end

    context 'and the commentable is a Package' do
      let(:comment) { create(:comment_package) }

      it_behaves_like 'rendering the body, who, when and the id'

      it 'renders the package name of the commenter' do
        expect(builder).to have_xpath("//comment_[contains(@package, '#{comment.commentable.name}')]")
      end
    end

    context 'and the commentable is Request' do
      let(:comment) { create(:comment_request) }

      it_behaves_like 'rendering the body, who, when and the id'

      it 'renders the request number of the commenter' do
        expect(builder).to have_xpath("//comment_[contains(@bsrequest, '#{comment.commentable.number}')]")
      end
    end
  end
end
