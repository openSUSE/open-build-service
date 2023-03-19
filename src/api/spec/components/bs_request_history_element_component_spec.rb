require 'rails_helper'

RSpec.describe BsRequestHistoryElementComponent, type: :component do
  let(:user) { create(:confirmed_user) }

  before do
    render_inline(described_class.new(element: element))
  end

  context 'for any kind of history elements' do
    let(:element) { create(:history_element_request_accepted, user: user, created_at: Time.now.utc - 1.day) }

    it 'displays an avatar' do
      expect(rendered_content).to have_selector("img[title='#{user.realname}']", count: 1)
    end

    it 'displays the name of the user involved' do
      expect(rendered_content).to have_text("#{user.realname} (#{user.login})")
    end

    it 'displays the time in words' do
      expect(rendered_content).to have_text('1 day ago')
    end

    it 'displays the element comment' do
      expect(rendered_content).to have_selector('.timeline-item-comment', text: element.comment)
    end
  end

  context 'with a HistoryElement::RequestAccepted' do
    let(:element) { create(:history_element_request_accepted, user: user) }

    it 'displays the right icon' do
      expect(rendered_content).to have_css('i.fa-check')
    end

    it 'describes the element action' do
      expect(rendered_content).to have_text('accepted request')
    end
  end

  context 'with a HistoryElement::RequestSuperseded' do
    let(:element) { create(:history_element_request_superseded, user: user) }

    it 'displays the right icon' do
      expect(rendered_content).to have_css('i.fa-code-commit')
    end

    it 'describes the element action' do
      expect(rendered_content).to have_text('superseded this request with')
    end
  end

  context 'with a HistoryElement::RequestReviewAdded' do
    context 'with review' do
      let(:element) { create(:history_element_request_review_added_with_review, user: user) }

      it 'displays the right icon' do
        expect(rendered_content).to have_css('i.fa-circle')
      end

      it 'describes the element action' do
        expect(rendered_content).to have_text('as a reviewer')
      end
    end

    context 'without review' do
      let(:element) { create(:history_element_request_review_added_without_review, user: user, description_extension: nil) }

      it 'displays the right icon' do
        expect(rendered_content).to have_css('i.fa-circle')
      end

      it 'describes the element action' do
        expect(rendered_content).to have_text('added a reviewer')
      end
    end
  end
end
