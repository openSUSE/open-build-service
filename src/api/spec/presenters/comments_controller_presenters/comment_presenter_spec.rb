require 'rails_helper'

RSpec.describe ::CommentsControllerPresenters::CommentPresenter do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:comment_project) { create(:comment_project, user: user) }
  let(:comment_package) { create(:comment_package, user: user) }

  describe 'Commenter is an User' do
    context 'for a project' do
      let(:comment_presenter) { CommentsControllerPresenters::CommentPresenter.new(comment_project, true) }

      it { expect(comment_presenter.attributes).to include(who: 'tom') }
      it { expect(comment_presenter.attributes).to include(id: comment_project.id) }
      it { expect(comment_presenter.attributes).to include(:project) }
    end

    context 'for a package' do
      let(:comment_presenter) { CommentsControllerPresenters::CommentPresenter.new(comment_package, true) }

      it { expect(comment_presenter.attributes).to include(:project) }
      it { expect(comment_presenter.attributes).to include(:package) }
    end
  end

  describe 'Commenter isn\'t an user' do
    let(:comment_presenter) { CommentsControllerPresenters::CommentPresenter.new(comment_package, false) }

    it { expect(comment_presenter.attributes).not_to include(:project) }
  end
end
