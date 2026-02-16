require 'spec_helper'

RSpec.describe PackageDatatable, type: :datatable do
  let(:project) { create(:project, name: 'test_project') }
  let(:package_with_scm) { create(:package, name: 'scm_pkg', project: project, scmsync: 'https://github.com/example/pkg.git') }
  let(:package_without_scm) { create(:package, name: 'no_scm_pkg', project: project) }
  let(:view_context) { double('view_context') }
  let(:params) { ActionController::Parameters.new({}) }
  let(:datatable) { PackageDatatable.new(params, project: project, view_context: view_context) }

  before do
    allow(view_context).to receive(:link_to) { |*args, &block| block ? block.call : args.first }
    allow(view_context).to receive(:package_show_path).and_return('/path')
    allow(view_context).to receive(:time_ago_in_words).and_return('2 days')
    allow(view_context).to receive(:tag).and_return(ActionController::Base.helpers.tag)
    allow(view_context).to receive(:safe_join) { |args| args.join(' ').html_safe }
  end

  describe '#data' do
    it 'includes SCM indicator when package has scmsync' do
      allow(datatable).to receive(:records).and_return([package_with_scm])
      data = datatable.data
      expect(data.first[:name]).to include('SCM')
    end

    it 'does not include SCM indicator when package has no scmsync' do
      allow(datatable).to receive(:records).and_return([package_without_scm])
      data = datatable.data
      expect(data.first[:name]).not_to include('SCM')
    end
  end
end
