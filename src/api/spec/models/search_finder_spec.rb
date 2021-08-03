require 'rails_helper'

RSpec.describe SearchFinder do
  describe 'validation' do
    context 'valid' do
      let(:finder) { described_class.new(what: :package) }

      it { expect(finder).to be_valid }
    end

    context 'invalid' do
      let(:finder) { described_class.new(what: :packaage) }

      it { expect(finder).not_to be_valid }
    end
  end

  describe 'search for package' do
    let!(:package) { create(:package, name: 'bar') }
    let(:finder) { described_class.new(what: :package, search_items: [package.id]) }

    it { expect(finder.call).to include(package) }

    describe 'instance variables' do
      before do
        finder.call
      end

      it { expect(finder.included_classes).to include(:project) }
    end
  end

  describe 'search for project' do
    let!(:project) { create(:project, name: 'foo') }

    context 'render all = false' do
      let(:finder) { described_class.new(what: :project, search_items: [project.id]) }

      it { expect(finder.call).to include(project) }
    end

    context 'render all = true' do
      let(:finder) { described_class.new(what: :project, render_all: true, search_items: [project.id]) }

      before do
        finder.call
      end

      it { expect(finder.call).to include(project) }
      it { expect(finder.included_classes).to include(:repositories) }
      it { expect(finder.relation.first.title).not_to be_nil }
    end
  end
end
