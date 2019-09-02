require 'rails_helper'

RSpec.describe Webui::ProjectHelper, type: :helper do
  describe '#project_bread_crumb' do
    let(:project) { create(:project_with_package) }

    before do
      @project = project.name
    end

    it 'creates a list with a link to projects list' do
      expect(project_bread_crumb).to eq([link_to('Projects', project_list_public_path)])
    end

    context "when it's called with a parameter" do
      it 'adds the content of the parameter to the list' do
        expect(project_bread_crumb('my label')).to eq([link_to('Projects', project_list_public_path), 'my label'])
      end
    end

    context 'when the project has parent projects' do
      let(:child_project) { create(:project_with_package, name: "#{project}:child") }

      before do
        @project = child_project
        @package = project.packages.first.name
      end

      it 'adds a link to the parent projects to the list' do
        expect(project_bread_crumb('Text')).to eq(
          [
            link_to('Projects', project_list_public_path),
            [
              link_to(project, project_show_path(project: project)),
              link_to('child', project_show_path(project: child_project))
            ],
            'Text'
          ]
        )
      end
    end

    context 'when @spider_bot is true' do
      before do
        @spider_bot = true
      end

      it { expect(project_bread_crumb).to be(nil) }
    end
  end

  describe '#format_seconds' do
    it 'shows a zero for the hour if under 3600 seconds' do
      expect(format_seconds(60)).to eq('0:01')
    end

    it 'shows hours and seconds properly' do
      expect(format_seconds(12_000)).to eq('3:20')
    end
  end

  describe '#rebuild_time_col' do
    skip
  end
end
