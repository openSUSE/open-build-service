RSpec.describe AccordionReviewsComponent, type: :component do
  context 'when testing the preview' do
    let(:user) { create(:confirmed_user, :with_home) }
    let!(:opened_review) { create(:review, by_user: user) }
    let!(:accepted_review) { create(:review, by_user: user, state: :accepted) }
    let!(:declined_review) { create(:review, by_user: user, state: :declined) }
    let(:source_prj) { create(:project) }
    let(:source_pkg) { create(:package, project: source_prj) }
    let(:target_prj) { user.home_project }
    let(:target_pkg) { create(:package, project: target_prj) }
    let(:action_attributes) do
      {
        type: 'submit',
        source_package: source_pkg,
        source_project: source_prj,
        target_project: target_prj,
        target_package: target_pkg
      }
    end

    before do
      create(:bs_request, action_attributes.merge(creator: user))
    end

    it 'renders the accordion reviews' do
      user.run_as do
        render_preview(:preview)
      end

      expect(rendered_content).to have_text('Accepted Review')
      expect(rendered_content).to have_text('Pending Review')
      expect(rendered_content).to have_text('Declined Review')
    end
  end
end
