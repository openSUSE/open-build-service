require 'rails_helper'

RSpec.describe WatchlistIconComponent, type: :component do
  let(:user) { create(:confirmed_user) }
  let(:project) { nil }
  let(:package) { nil }
  let(:bs_request) { nil }

  context 'when the item is not in the watchlist yet' do
    before do
      render_inline(described_class.new(user: user, current_object: item, project: project, package: package, bs_request: bs_request))
    end

    context 'and the item is a project' do
      let(:project) { create(:project) }
      let!(:item) { project }

      it 'displays the icon to add item to watchlist' do
        expect(rendered_content).to have_selector('a > i.far.fa-eye')
        expect(rendered_content).to have_selector('a', text: 'Watch')
      end
    end

    context 'and the item is a package' do
      let(:project) { create(:project) }
      let(:package) { create(:package, project: project) }
      let!(:item) { package }

      it 'displays the icon to add item to watchlist' do
        expect(rendered_content).to have_selector('a > i.far.fa-eye')
        expect(rendered_content).to have_text('Watch')
      end
    end

    context 'and the item is a request' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let!(:item) { bs_request }

      it 'displays the icon to add item to watchlist' do
        expect(rendered_content).to have_selector('a > i.far.fa-eye')
        expect(rendered_content).to have_text('Watch')
      end
    end

    context 'and the item is a remote project' do
      let(:project) { create(:remote_project) }
      let!(:item) { project }

      it 'does not display a watchlist icon' do
        expect(rendered_content).not_to have_selector('i.fas.fa-eye')
      end
    end

    context 'and the item is a package from a remote project' do
      let(:project) { create(:remote_project) }
      let(:package) { create(:package, project: create(:project, name: 'another_project')) }
      let!(:item) { package }

      it 'does not display the watchlist icon' do
        expect(rendered_content).not_to have_selector('i.far.fa-eye')
      end
    end
  end

  context 'when the item is already in the watchlist' do
    before do
      user.watched_items.create(watchable: item)
      item.reload
      render_inline(described_class.new(user: user, current_object: item, project: project, package: package, bs_request: bs_request))
    end

    context 'and the item is a project' do
      let(:project) { create(:project) }
      let!(:item) { project }

      it 'displays the icon to remove item from watchlist' do
        expect(rendered_content).to have_selector('a > i.fas.fa-eye')
        expect(rendered_content).to have_text('Unwatch')
      end
    end

    context 'and the item is a package' do
      let(:project) { create(:project) }
      let(:package) { create(:package, project: project) }
      let!(:item) { package }

      it 'displays the icon to remove item from watchlist' do
        expect(rendered_content).to have_selector('a > i.fas.fa-eye')
        expect(rendered_content).to have_text('Unwatch')
      end
    end

    context 'and the item is a request' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let!(:item) { bs_request }

      it 'displays the icon to remove item from watchlist' do
        expect(rendered_content).to have_selector('a > i.fas.fa-eye')
        expect(rendered_content).to have_text('Unwatch')
      end
    end
  end
end
