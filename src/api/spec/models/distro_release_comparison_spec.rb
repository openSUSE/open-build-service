RSpec.describe DistroReleaseComparison do
  subject(:comparison) { described_class.new(base_release: base_release, target_release: target_release) }

  let(:architecture) { create(:architecture) }
  let(:base_project) { create(:project) }
  let(:target_project) { create(:project) }
  let(:base_release) do
    create(:distro_release, name: '15.6', repositories: [create(:repository, project: base_project)], architectures: [architecture])
  end
  let(:target_release) do
    create(:distro_release, name: '16.0', distro: base_release.distro,
                            repositories: [create(:repository, project: target_project)], architectures: [architecture])
  end

  before do
    { 'same' => '2.4.1-3.5', 'newer_in_target' => '0.27.0-bp161.1.2',
      'newer_in_base' => '3.3.1+28b6d8afc-1.1', 'only_in_base' => '1.0~rc1' }.each do |name, version|
      create(:package_version_local, package: create(:package, project: base_project, name: name), version: version)
    end
    { 'same' => '2.4.1-bp161.1.2', 'newer_in_target' => '0.28.0-1.2',
      'newer_in_base' => '3.1.5~git9.4914e222d', 'only_in_target' => '0.16+git20101166' }.each do |name, version|
      create(:package_version_local, package: create(:package, project: target_project, name: name), version: version)
    end
  end

  describe '#rows' do
    it 'classifies every package of both releases' do
      expect(comparison.rows.to_h { |row| [row.package_name, row.status] }).to eq('newer_in_base' => :older,
                                                                                  'newer_in_target' => :newer,
                                                                                  'only_in_base' => :only_in_base,
                                                                                  'only_in_target' => :only_in_target,
                                                                                  'same' => :same)
    end

    it 'keeps the versions of both releases, sorted by package name' do
      expect(comparison.rows.map(&:package_name)).to eq(%w[newer_in_base newer_in_target only_in_base only_in_target same])
      expect(comparison.rows.find { |row| row.package_name == 'only_in_base' }).to have_attributes(base_version: '1.0~rc1', target_version: nil)
    end
  end

  describe '#counts' do
    it 'counts the packages per status' do
      expect(comparison.counts).to eq(older: 1, newer: 1, only_in_base: 1, only_in_target: 1, same: 1)
    end
  end
end
