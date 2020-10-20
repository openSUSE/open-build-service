require 'rails_helper'

RSpec.describe AutocompleteFinder::Project, vcr: true do
  describe '#call' do
    before do
      create(:project, name: 'foo')
      create(:project, name: 'foobar')
      create(:project, name: 'barbar')
    end

    context 'limit the number of found packages to 1' do
      let(:autocomplete_projects_finder) { AutocompleteFinder::Project.new(Project.all, 'foo', limit: 1) }

      it { expect(autocomplete_projects_finder.call).to match_array(Project.where(name: 'foo')) }
    end

    context 'find all projects with start with foo' do
      let(:autocomplete_projects_finder) { AutocompleteFinder::Project.new(Project.all, 'foo') }

      it { expect(autocomplete_projects_finder.call).to match_array(Project.where('name LIKE ?', 'foo%')) }
    end
  end
end
