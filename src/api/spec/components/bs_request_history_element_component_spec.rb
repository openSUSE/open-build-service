RSpec.describe BsRequestHistoryElementComponent, type: :component do
  let(:user) { create(:confirmed_user) }
  let(:reviews) { [] }

  before do
    render_inline(described_class.new(element: element, request_reviews_for_non_staging_projects: reviews))
  end

  context 'for any kind of history elements' do
    let(:element) { travel_to(1.day.ago) { create(:history_element_request_accepted, user: user) } }

    it 'displays the name of the user involved' do
      expect(rendered_content).to have_text("#{user.realname} (#{user.login})")
    end

    it 'displays the time in words' do
      expect(rendered_content).to have_text('1 day ago')
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

    context 'with pending reviews' do
      let(:reviews) { build_list(:review, 2, state: 'new') }

      it 'describes the element action and mentions dismissed reviews' do
        expect(rendered_content).to have_text('accepted request and dismissed pending reviews')
      end
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

    context 'with review for group' do
      let(:element) { create(:history_element_request_review_accepted_with_review_by_group, user: user) }

      it 'displays the right icon' do
        expect(rendered_content).to have_css('i.fa-check')
      end

      it 'describes the element action' do
        expect(rendered_content).to have_text('accepted review')
        expect(rendered_content).to have_text("for\ngroup")
      end
    end

    context 'with review for project' do
      let(:element) { create(:history_element_request_review_accepted_with_review_by_project, user: user) }

      it 'displays the right icon' do
        expect(rendered_content).to have_css('i.fa-check')
      end

      it 'describes the element action' do
        expect(rendered_content).to have_text('accepted review')
        expect(rendered_content).to have_text("for\nproject")
      end
    end

    context 'with review for package' do
      let(:element) { create(:history_element_request_review_accepted_with_review_by_package, user: user) }

      it 'displays the right icon' do
        expect(rendered_content).to have_css('i.fa-check')
      end

      it 'describes the element action' do
        expect(rendered_content).to have_text('accepted review')
        expect(rendered_content).to have_text("for\npackage")
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
