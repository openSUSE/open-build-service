require 'rails_helper'

RSpec.describe WatchedItemsListComponent, type: :component do
  let(:user) { create(:confirmed_user) }
  let(:current_object) { create(:package) }

  context 'when dealing with packages' do
    context 'and the user is not watching packages' do
      before do
        render_inline(described_class.new(items: [], class_name: 'Package', current_object: current_object))
      end

      it 'does not show any watched package in the list' do
        expect(rendered_content).to have_text('There are no packages in the watchlist yet.')
      end
    end

    context 'and the user is watching some packages' do
      # packages watched by the user
      let(:packages) { create_list(:package, 2) }

      before do
        render_inline(described_class.new(items: packages, class_name: 'Package', current_object: current_object))
      end

      it 'does show the watched package in the list' do
        expect(rendered_content).not_to have_text('There are no packages in the watchlist yet.')
        expect(rendered_content).to have_text(packages.sample.name)
      end
    end
  end

  context 'when dealing with projects' do
    context 'and the user is not watching projects' do
      before do
        render_inline(described_class.new(items: [], class_name: 'Project', current_object: current_object))
      end

      it 'does not show any watched project in the list' do
        expect(rendered_content).to have_text('There are no projects in the watchlist yet.')
      end
    end

    context 'and the user is watching some projects' do
      # projects watched by the user
      let(:projects) { create_list(:project, 2) }

      before do
        render_inline(described_class.new(items: projects, class_name: 'Project', current_object: current_object))
      end

      it 'does show the watched project in the list' do
        expect(rendered_content).not_to have_text('There are no projects in the watchlist yet.')
        expect(rendered_content).to have_text(projects.sample.name)
      end
    end
  end

  context 'when dealing with requests' do
    context 'and the user is not watching requests' do
      before do
        render_inline(described_class.new(items: [], class_name: 'BsRequest', current_object: current_object))
      end

      it 'does not show any watched request in the list' do
        expect(rendered_content).to have_text('There are no requests in the watchlist yet.')
      end
    end

    context 'and the user is watching some requests' do
      # requests watched by the user
      let(:requests) { create_list(:bs_request_with_submit_action, 2) }

      before do
        render_inline(described_class.new(items: requests, class_name: 'BsRequest', current_object: current_object))
      end

      it 'does show the watched request in the list' do
        expect(rendered_content).not_to have_text('There are no requests in the watchlist yet.')
        expect(rendered_content).to have_text("##{requests.sample.number} Submit")
      end
    end
  end
end
