require 'rails_helper'

RSpec.describe BsRequestHistoryElementComponent, type: :component do
  # rubocop:disable Lint/EmptyBlock
  shared_context 'raising an exception warning the user to provide an history element' do
  end
  # rubocop:enable Lint/EmptyBlock

  # rubocop:disable RSpec/RepeatedExampleGroupBody
  context 'when the element provided is not present' do
    it_behaves_like 'raising an exception warning the user to provide an history element'
  end

  context 'when the element provided is not a history element' do
    it_behaves_like 'raising an exception warning the user to provide an history element'
  end

  context 'when the element provided is a history element superseded' do
    it 'renders the element telling this request was superseded'
    it 'renders the element comment'
  end

  context 'when the element provided is a history element accepted' do
    it 'renders the element action'
    it 'renders the element comment'
  end

  context 'when the element provided is a history element about review added' do
    context 'and review is known' do
      it 'renders the element action'
      it 'renders the element comment'
    end

    context 'and review is unknown' do
      it 'renders the element action'
      it 'renders the element comment'
    end
  end
  # rubocop:enable RSpec/RepeatedExampleGroupBody
end
