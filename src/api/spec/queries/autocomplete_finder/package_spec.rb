require 'rails_helper'

RSpec.describe AutocompleteFinder::Package, vcr: true do
  describe '#call' do
    before do
      create(:package, name: 'foo')
      create(:package, name: 'foobar')
      create(:package, name: 'barbar')
    end

    context 'limit the number of found packages to 1' do
      let(:autocomplete_packages_finder) { AutocompleteFinder::Package.new(Package.all, 'foo', limit: 1) }

      it { expect(autocomplete_packages_finder.call).to match_array(Package.where(name: 'foo')) }
    end

    context 'find all packages with start with foo' do
      let(:autocomplete_packages_finder) { AutocompleteFinder::Package.new(Package.all, 'foo') }

      it { expect(autocomplete_packages_finder.call).to match_array(Package.where('name LIKE ?', 'foo%')) }
    end
  end
end
