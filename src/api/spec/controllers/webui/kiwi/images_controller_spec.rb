require 'rails_helper'

# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::Kiwi::ImagesController, type: :controller, vcr: true do
  let(:project) { create(:project, name: 'fake_project') }

  describe 'GET #import_from_package' do
    context 'without a kiwi file' do
      let(:package_without_kiwi_file) { create(:package_with_kiwi_image, name: 'package_without_kiwi_file', project: project) }

      before do
        get :import_from_package, params: { package_id: package_without_kiwi_file.id }
      end

      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).to eq('There is no KIWI file') }
    end

    context 'with a kiwi file' do
      context 'that is a valid kiwi file' do
        let(:kiwi_image) do
          create(:kiwi_image_with_package, name: 'package_with_valid_kiwi_file', project: project, with_kiwi_file: true)
        end

        before do
          get :import_from_package, params: { package_id: kiwi_image.package.id }
        end

        it { expect(response).to redirect_to(kiwi_image_repositories_path(kiwi_image)) }
      end

      context 'that is an invalid kiwi file' do
        include_context 'an invalid kiwi image xml'

        let(:package_with_kiwi_image) do
          create(:package_with_kiwi_file, name: 'package_with_invalid_kiwi_file', project: project, kiwi_file_content: invalid_kiwi_xml)
        end

        before do
          get :import_from_package, params: { package_id: package_with_kiwi_image.id }
        end

        it { expect(response).to redirect_to(root_path) }
        it { expect(flash[:error]).not_to be_nil }
      end
    end
  end

  describe 'GET #show' do
    let(:package) { create(:package_with_kiwi_image, name: 'fake_package', project: project) }

    before do
      get :show, params: { id: package.kiwi_image_id }
    end

    it { expect(response.content_type).to eq("application/json") }
    it { expect(response).to have_http_status(:ok) }
  end
end
