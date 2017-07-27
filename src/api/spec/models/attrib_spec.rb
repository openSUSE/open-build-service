require 'rails_helper'

RSpec.describe Attrib, :type => :model do
  let(:attribute) { create(:attrib, project: create(:project)) }
  let(:project) { create(:project) }
  let(:package) { create(:package) }

  describe "#fullname" do
    it { expect(attribute.fullname).to eq("#{attribute.namespace}:#{attribute.name}") }
  end

  describe "#container" do
    context "attribute with project" do
      it { expect(attribute.container).to eq(attribute.project) }
    end

    context "attribute with package" do
      let(:attribute_with_package) { create(:attrib, package: package) }

      it { expect(attribute_with_package.container).to eq(package) }
    end
  end

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
