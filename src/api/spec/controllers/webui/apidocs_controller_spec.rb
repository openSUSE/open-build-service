require 'rails_helper'

RSpec.describe Webui::ApidocsController, type: :controller do
  describe 'GET #index' do
    context 'correct setup' do
      let(:tmp_dir) { Dir.mktmpdir }
      let(:tmp_file) { "#{tmp_dir}/index.html" }

      before do
        File.open(tmp_file, 'w') do |f|
          f.write('<html><head></head><body></body></html>')
        end
        CONFIG['apidocs_location'] = tmp_dir

        get :index
      end

      after do
        File.delete(tmp_file)
        Dir.rmdir(tmp_dir)
      end

      it 'responses without error' do
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('text/html')
      end
    end

    context 'broken setup' do
      before do
        stub_const('CONFIG', CONFIG.merge('apidocs_location' => 'non/existent/subdirectory'))
      end

      it 'errors and redirects' do
        expect(Rails.logger).to receive(:error).with(
          "Unable to load apidocs index file from #{CONFIG['apidocs_location']}. Did you create the apidocs?"
        )

        get :index

        expect(flash[:error]).to eq('Unable to load API documentation.')
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET #file' do
    context 'with an existing file' do
      let(:tmp_file) do
        Tempfile.open(['apidoc_file', '.xml']) do |f|
          f.write '<xml></xml>'
          f
        end
      end

      before do
        stub_const('CONFIG', CONFIG.merge('schema_location' => Dir.tmpdir))
        get :file, params: { filename: File.basename(tmp_file.path) }
      end

      it 'reponses without error' do
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('text/xml')
      end
    end

    context 'with a non existing file' do
      let(:non_existing_filename) { 'this_file_must_not_exist' }

      before do
        get :file, params: { filename: non_existing_filename }
      end

      it 'errors and redirects' do
        expect(flash[:error]).to eq("File not found: #{non_existing_filename}")
        expect(response).to redirect_to(controller: 'webui/apidocs', action: 'index')
      end
    end
  end
end
