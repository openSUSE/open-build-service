RSpec.describe PackageVersionLabeler, type: :module do
  let(:test_class) do
    Class.new do
      include PackageVersionLabeler
    end.new
  end

  let(:project) { create(:project, name: 'Factory') }
  let(:package) { create(:package, project: project, name: 'apache2') }

  describe '#update_package_version_labels' do
    context 'when upstream version is missing' do
      it 'assigns the "No Upstream" label' do
        allow(package).to receive(:latest_upstream_version).and_return(nil)

        test_class.update_package_version_labels(package_ids: [package.id])

        label = package.reload.labels.first
        expect(label.label_template.name).to eq('No Upstream')
        expect(label.label_template.color).to eq('#f6d32d')
      end
    end

    context 'when local and upstream versions match' do
      it 'assigns the "Up to date" label' do
        create(:package_version_local, package: package, version: '1.0.0')
        create(:package_version_upstream, package: package, version: '1.0.0')

        test_class.update_package_version_labels(package_ids: [package.id])

        expect(package.reload.labels.first.label_template.name).to eq('Up to date')
      end
    end

    context 'when local and upstream versions differ' do
      it 'assigns the "Outdated" label' do
        create(:package_version_local, package: package, version: '1.0.0')
        create(:package_version_upstream, package: package, version: '2.0.0')

        test_class.update_package_version_labels(package_ids: [package.id])

        expect(package.reload.labels.first.label_template.name).to eq('Outdated')
      end
    end

    context 'when label templates already exist on project' do
      it 'does not recreate label templates' do
        project.label_templates.create!(name: 'Outdated', color: '#e01b24')

        # 'Outdated' label template exists at this point, so only the two remaining
        # label templates ('up to date' and 'no upstream') should be added
        expect do
          test_class.update_package_version_labels(package_ids: [package.id])
        end.to change(LabelTemplate, :count).by(2)
      end
    end

    context 'when version label is already assigned to package' do
      it 'does not delete and recreate the same label if it is already correct' do
        test_class.update_package_version_labels(package_ids: [package.id])
        initial_label_id = package.labels.first.id

        test_class.update_package_version_labels(package_ids: [package.id])

        expect(package.reload.labels.first.id).to eq(initial_label_id)
      end
    end
  end
end
