require 'rails_helper'

RSpec.describe Attrib, :type => :model do
  let(:attribute) { create(:attrib, project: create(:project)) }
  let(:project) { create(:project) }
  let(:package) { create(:package) }

  context "#container=" do
    context "assigning a project" do
      before do
        attribute.container = project
      end

      it { expect(attribute.container).to be(project) }
      it { expect(attribute.project).to be(project) }
      it { expect(attribute.package).to be_nil }

      context "and then assigning a package" do
        before do
          attribute.container = package
        end

        it { expect(attribute.container).to be(package) }
        it { expect(attribute.project).to be(package.project) }
        it { expect(attribute.package).to be(package) }
      end
    end

    context "assigning a package" do
      before do
        attribute.container = package
      end

      it { expect(attribute.container).to be(package) }
      it { expect(attribute.project).to be(package.project) }
      it { expect(attribute.package).to be(package) }

      context "and then assigning a project" do
        before do
          attribute.container = project
        end

        it { expect(attribute.container).to be(package) }
        it { expect(attribute.project).to be(package.project) }
        it { expect(attribute.package).to be(package) }
      end
    end
  end
end
