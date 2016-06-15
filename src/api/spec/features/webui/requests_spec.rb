require "browser_helper"

RSpec.feature "Requests", :type => :feature, :js => true do
  RSpec.shared_examples "expandable element" do
    let!(:bs_request) { create(:bs_request, description: "a long text - " * 200) }
    let!(:user) { create(:confirmed_user) }

    scenario "expanding a text field" do
      invalid_word_count = valid_word_count + 1

      visit request_show_path(bs_request)
      within(element) do
        expect(page).to have_text("a long text - " * valid_word_count)
        expect(page).not_to have_text("a long text - " * invalid_word_count)

        click_link("[+]")
        expect(page).to have_text("a long text - "* 200)

        click_link("[-]")
        expect(page).to have_text("a long text - " * valid_word_count)
        expect(page).not_to have_text("a long text - " * invalid_word_count)
      end
    end
  end

  context "request show page" do
    describe "request description field" do
      it_behaves_like "expandable element" do
        let(:element) { "pre#description-text" }
        let(:valid_word_count) { 21 }
      end
    end

    describe "request history entries" do
      it_behaves_like "expandable element" do
        let(:element) { ".expandable_event_comment" }
        let(:valid_word_count) { 3 }
      end
    end
  end
end
