require 'rails_helper'

RSpec.describe Webui::ProjectHelper, type: :helper do
  describe '#show_status_comment' do
    skip
  end

  describe '#project_bread_crumb' do
    skip
  end

  describe '#format_seconds' do
    skip
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
    skip
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
