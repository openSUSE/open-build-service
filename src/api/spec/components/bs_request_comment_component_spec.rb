require 'rails_helper'

RSpec.describe BsRequestCommentComponent, type: :component do
  context 'when we have a comment' do
    context 'when we have a commentable' do
      context 'when rendering the first level of a comment thread' do
        it 'renders the comment'
        it 'renders the child comments underneath'
      end
    end

    context 'when we do not have a commetable' do
      it 'flashes an error'
    end
  end

  context 'when we do not have a comment' do
    it 'renders nothing'
  end
end
