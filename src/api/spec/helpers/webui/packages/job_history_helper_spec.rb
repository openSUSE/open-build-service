# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webui::Packages::JobHistoryHelper, type: :helper do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { user.home_project }
  let(:package) { create(:package, name: 'my_package', project: project) }

  describe '#job_history_bread_crumb' do
    let(:breadcrumb) do
      [
        '<a href="/project/list_public">Projects</a>',
        ['<a href="/project/show/home:tom">home:tom</a>'],
        '<a href="/package/show/home:tom/my_package">my_package</a>',
        'Job history'
      ]
    end

    before do
      @project = project
    end

    it { expect(job_history_breadcrumb(project, package, 'Job history')).to eq(breadcrumb) }
  end

  describe '#link_to_package_from_job_history' do
    let(:job_history) { LocalJobHistory.new(srcmd5: '12312312', revision: '1') }

    context 'with a link' do
      let(:result) { 'package/show/home:tom/my_package?srcmd5=12312312' }
      it { expect(link_to_package_from_job_history(project, package, job_history, true)).to include(result) }
    end

    context 'without a link' do
      let(:result) { 'package/show/home:tom/my_package?rev=1' }
      it { expect(link_to_package_from_job_history(project, package, job_history, false)).to include(result) }
    end
  end
end
