require 'rails_helper'

RSpec.describe Attrib do
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

  describe "validations" do
    before do
      subject.valid?
    end

    describe "#validate_value_count" do
      let(:attrib_value) { build(:attrib_value, value: 'Random value 1') }
      let(:attrib_allowed_value) { build(:attrib_allowed_value, value: 'Random value 2') }
      let(:attrib_type) { create(:attrib_type_with_namespace, allowed_values: [attrib_allowed_value]) }

      subject { build(:attrib, project: project, attrib_type: attrib_type, values: [attrib_value]) }

      it { expect(subject.errors.full_messages).to match_array(["Values Value 'Random value 1' is not allowed. Please use one of: Random value 2"]) }
    end

    describe "#validate_issues" do
      let(:issue_tracker) { create(:issue_tracker) }
      let(:issue) { create(:issue, issue_tracker_id: issue_tracker.id) }
      let(:attrib_type) { create(:attrib_type_with_namespace, issue_list: false) }

      subject { build(:attrib, project: project, attrib_type: attrib_type, issues: [issue]) }

      it { expect(subject.errors.full_messages).to match_array(["Issues can't have issues"]) }
    end

    describe "#validate_allowed_values_for_attrib_type" do
      let(:attrib_type) { create(:attrib_type_with_namespace, value_count: 1) }

      subject { build(:attrib, project: project, attrib_type: attrib_type, values: []) }

      it { expect(subject.errors.full_messages).to match_array(['Values has 0 values, but only 1 are allowed']) }
    end
  end
end
