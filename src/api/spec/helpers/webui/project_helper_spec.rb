# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webui::ProjectHelper, type: :helper do
  describe '#show_status_comment' do
    skip
  end

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

      it { expect(project_bread_crumb).to be nil }
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

  describe '#short_incident_name' do
    skip
  end

  describe '#patchinfo_rating_color' do
    it 'returns the right color' do
      expect(patchinfo_rating_color('important')).to eq('red')
    end

    it 'returns no color for an inexistent rating' do
      expect(patchinfo_rating_color(nil)).to eq('')
    end
  end

  describe '#patchinfo_category_color' do
    it 'returns the right color' do
      expect(patchinfo_category_color('security')).to eq('maroon')
    end

    it 'returns no color for an inexistent category' do
      expect(patchinfo_rating_color(nil)).to eq('')
    end
  end

  describe '#incident_issue_color' do
    it 'returns red if there are no patchinfo issues' do
      expect(incident_issue_color(0, 0)).to eq('red')
    end

    it 'returns green if package and patchinfo have the same amount of issues' do
      expect(incident_issue_color(20, 20)).to eq('green')
    end

    it 'returns olive if there are more package issues than patchinfo issues' do
      expect(incident_issue_color(20, 30)).to eq('olive')
    end

    it 'returns red if there are more patchinfo issues than package issues' do
      expect(incident_issue_color(30, 20)).to eq('red')
    end
  end

  describe '#map_request_state_to_flag' do
    it 'returns the right flag' do
      expect(map_request_state_to_flag('new')).to eq('flag_green')
    end

    it 'returns no flag if passed nothing' do
      expect(map_request_state_to_flag(nil)).to eq('')
    end
  end

  describe '#escape_list' do
    it 'html escapes an array of strings' do
      input = ['<p>home:Iggy</p>', '<p>This is a paragraph</p>']
      output = "['&lt;p&gt;home:Iggy&lt;\\/p&gt;'],['&lt;p&gt;This is a paragraph&lt;\\/p&gt;']"
      expect(escape_list(input)).to eq(output)
    end
  end
end
