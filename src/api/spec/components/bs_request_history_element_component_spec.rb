require 'rails_helper'

RSpec.describe BsRequestHistoryElementComponent, type: :component do
  let(:user) { create(:confirmed_user) }

  it 'fails when the history element is not passed' do
    expect { render_inline(described_class.new) }.to raise_error(ArgumentError, 'missing keyword: :element')
  end

  context 'with a HistoryElement::RequestAccepted' do
    let(:element) { create(:history_element_request_accepted, user: user) }

    it 'describes the element action' do
      expect(render_inline(described_class.new(element: element))).to have_text('accepted request')
    end

    it 'displays the right icon' do
      expect(render_inline(described_class.new(element: element))).to have_css('i.fa-check')
    end

    it 'displays the element comment' do
      expect(render_inline(described_class.new(element: element))).to have_text(element.comment)
    end
  end

  context 'with a HistoryElement::RequestSuperseded' do
    let(:element) { create(:history_element_request_superseded, user: user) }

    it 'describes the element action' do
      expect(render_inline(described_class.new(element: element))).to have_text('superseded this request with')
    end

    it 'displays the right icon' do
      expect(render_inline(described_class.new(element: element))).to have_css('i.fa-code-commit')
    end

    it 'displays the element comment' do
      expect(render_inline(described_class.new(element: element))).to have_text(element.comment)
    end
  end

  context 'with a HistoryElement::RequestReviewAdded' do
    context 'with review' do
      let(:element) { create(:history_element_request_review_added_with_review, user: user) }

      it 'describes the element action' do
        expect(render_inline(described_class.new(element: element))).to have_text('as a reviewer')
      end

      it 'displays the right icon' do
        expect(render_inline(described_class.new(element: element))).to have_css('i.fa-circle')
      end

      it 'displays the element comment' do
        expect(render_inline(described_class.new(element: element))).to have_text(element.comment)
      end
    end

    context 'without review' do
      let(:element) { create(:history_element_request_review_added_without_review, user: user, description_extension: nil) }

      it 'describes the element action' do
        expect(render_inline(described_class.new(element: element))).to have_text('added a reviewer')
      end

      it 'displays the right icon' do
        expect(render_inline(described_class.new(element: element))).to have_css('i.fa-circle')
      end

      it 'displays the element comment' do
        expect(render_inline(described_class.new(element: element))).to have_text(element.comment)
      end
    end
  end
end
