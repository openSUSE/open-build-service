require 'rails_helper'

RSpec.describe DiffComponent, type: :component, vcr: true do
  let(:target_project) { create(:project, name: 'target_project') }
  let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
  let(:file_name) { 'somefile.txt' }
  let(:target_package) { create(:package_with_file, name: 'target_package', project: target_project, file_name: file_name, file_content: '# This will be replaced') }
  let(:source_package) { create(:package_with_file, name: 'source_package', project: source_project, file_name: file_name, file_content: '# This is the new text') }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           target_package: target_package,
           source_package: source_package)
  end
  let(:bs_request_opts) { { filelimit: nil, tarlimit: nil, diff_to_superseded: nil, diffs: true, cacheonly: 1 } }

  context 'with a request having a submit action' do
    before do
      action = bs_request.send(:action_details, bs_request_opts, xml: bs_request.bs_request_actions.last)
      render_inline(described_class.new(diff: action[:sourcediff].first['files'].values.last['diff']['_content'], file_index: 3))
    end

    it 'renders the diff' do
      expect(rendered_content).to have_text('-# This will be replaced')
      expect(rendered_content).to have_text('+# This is the new text')
    end
  end
end
