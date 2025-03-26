RSpec.describe SourcediffComponent, :vcr, type: :component do
  let(:target_project) { create(:project, name: 'target_project') }
  let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
  let(:file_name) { 'somefile.spec' }
  let(:target_package) { create(:package_with_file, name: 'target_package', project: target_project, file_name: file_name, file_content: '# This will be replaced') }
  let(:source_package) { create(:package_with_file, name: 'source_package', project: source_project, file_name: file_name, file_content: '# This is the new text') }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           target_package: target_package,
           source_package: source_package)
  end
  let(:first_file_url) { Rails.application.routes.url_helpers.request_changes_diff_path(number: bs_request.number, request_action_id: bs_request.bs_request_actions.first.id, filename: file_name, file_index: 0) }

  context 'with a request with a submit action' do
    before do
      render_inline(described_class.new(bs_request: bs_request, action: bs_request.bs_request_actions.last))
    end

    it 'renders the turbo frame' do
      expect(rendered_content).to have_css("turbo-frame#file-0[loading=\"lazy\"][src=\"#{first_file_url}\"]")
    end
  end

  context 'when testing the preview' do
    before { bs_request }

    it 'renders the preview' do
      render_preview(:preview)

      expect(rendered_content).to have_css("turbo-frame#file-0[loading=\"lazy\"][src=\"#{first_file_url}\"]")
    end
  end
end
