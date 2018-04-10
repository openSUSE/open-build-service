# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webui::PatchinfoHelper, type: :helper do
  describe '#patchinfo_bread_crumb' do
    let(:project) { create(:project_with_package) }

    before do
      @project = project.name
      @package = project.packages.first.name
    end

    it 'creates a list of project_bread_crumb links, link to the patchinfo package' do
      expect(patchinfo_bread_crumb).to eq([
        project_bread_crumb,
        link_to(@package, package_show_path(project: @project, package: @package))
      ].flatten)
    end

    it 'the parameter content to the list' do
      expect(patchinfo_bread_crumb('Text')).to eq([
        project_bread_crumb,
        link_to(@package, package_show_path(project: @project, package: @package)),
        'Text'
      ].flatten)
    end
  end
end
