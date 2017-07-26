require 'rails_helper'

RSpec.describe Attrib, :type => :model do
  let(:attribute) { create(:attrib, project: create(:project)) }
  let(:project) { create(:project) }
  let(:package) { create(:package) }

  context "#container=" do
    it "sets the project" do
      attribute.container = project
      expect(attribute.container).to be(project)
    end

    it "sets the package" do
      attribute.container = package
      expect(attribute.container).to be(package)
    end
  end
end
