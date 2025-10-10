RSpec.describe Attrib do
  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project) }
  let(:package) { create(:package) }
  let(:attribute) { build(:attrib, project: create(:project)) }

  describe '#fullname' do
    it { expect(attribute.fullname).to eq("#{attribute.namespace}:#{attribute.name}") }
  end

  describe '#container' do
    context 'attribute with project' do
      it { expect(attribute.container).to eq(attribute.project) }
    end

    context 'attribute with package' do
      it 'saves the proper container' do
        login user
        attribute_with_package = create(:attrib, package: package)
        expect(attribute_with_package.container).to eq(package)
      end
    end
  end

  describe '#container=' do
    context 'assigning a project' do
      before do
        attribute.container = project
      end

      it { expect(attribute.container).to be(project) }
      it { expect(attribute.project).to be(project) }
      it { expect(attribute.package).to be_nil }

      context 'and then assigning a package' do
        before do
          attribute.container = package
        end

        it { expect(attribute.container).to be(package) }
        it { expect(attribute.project).to be(package.project) }
        it { expect(attribute.package).to be(package) }
      end
    end

    context 'assigning a package' do
      before do
        attribute.container = package
      end

      it { expect(attribute.container).to be(package) }
      it { expect(attribute.project).to be(package.project) }
      it { expect(attribute.package).to be(package) }

      context 'and then assigning a project' do
        before do
          attribute.container = project
        end

        it { expect(attribute.container).to be(package) }
        it { expect(attribute.project).to be(package.project) }
        it { expect(attribute.package).to be(package) }
      end
    end
  end

  describe '#project' do
    context 'attribute with project' do
      let(:attribute_with_project) { build(:attrib, project: project) }

      it { expect(attribute_with_project.project).to eq(project) }
    end

    context 'attribute with package' do
      it 'has the proper project' do
        login user
        attribute_with_package = create(:attrib, package: package)
        expect(attribute_with_package.project).to eq(package.project)
      end
    end
  end

  describe '#update_with_associations' do
    context 'without issues and without values' do
      before do
        login user
        attribute.save
      end

      it { expect(attribute.update_with_associations).to be(false) }

      context 'add an issue' do
        subject { attribute_with_type_issue.update_with_associations([], [issue]) }

        let(:issue_tracker) { create(:issue_tracker) }
        let(:issue) { create(:issue, issue_tracker_id: issue_tracker.id) }
        let(:attrib_type_issue) { create(:attrib_type, issue_list: true) }
        let(:attribute_with_type_issue) { build(:attrib, project: project, attrib_type: attrib_type_issue) }

        it { expect(subject).to be(true) }
        it { expect { subject }.to change { attribute_with_type_issue.issues.count }.by(1) }
      end

      context 'add a value' do
        subject { attribute.update_with_associations([attrib_value], []) }

        let(:attrib_value) { build(:attrib_value) }

        it { expect(subject).to be(true) }
        it { expect { subject }.to change { attribute.values.count }.by(1) }
      end

      context 'values list' do
        let(:values1) { %w[blue green] }
        let(:values2) { %w[green blue] }

        it 'resorts attribute values' do
          expect(attribute.update_with_associations(values1, [])).to be(true)
          expect(attribute.values.map(&:value)).to eq(values1)
          expect(attribute.update_with_associations(values2, [])).to be(true)
          expect(attribute.values.map(&:value)).to eq(values2)
        end
      end
    end
  end

  describe 'validations' do
    before do
      login user
      subject.valid?
    end

    describe '#validate_value_count' do
      subject { build(:attrib, project: project, attrib_type: attrib_type, values: [attrib_value]) }

      let(:attrib_value) { build(:attrib_value, value: 'Not allowed value') }
      let(:attrib_allowed_value) { build(:attrib_allowed_value, value: 'Allowed value') }
      let(:attrib_type) { create(:attrib_type, allowed_values: [attrib_allowed_value]) }

      it {
        expect(subject.errors.full_messages).to contain_exactly("Values Value 'Not allowed value' is not allowed. Please use one of: Allowed value")
      }
    end

    describe '#validate_issues' do
      subject { build(:attrib, project: project, attrib_type: attrib_type, issues: [issue]) }

      let(:issue) { create(:issue_with_tracker) }
      let(:attrib_type) { create(:attrib_type, issue_list: false) }

      it { expect(subject.errors.full_messages).to contain_exactly("Issues can't have issues") }
    end

    describe '#validate_allowed_values_for_attrib_type' do
      subject { build(:attrib, project: project, attrib_type: attrib_type, values: []) }

      let(:attrib_type) { create(:attrib_type, value_count: 1) }

      it { expect(subject.errors.full_messages).to contain_exactly('Values has 0 values, but only 1 are allowed') }
    end
  end
end
