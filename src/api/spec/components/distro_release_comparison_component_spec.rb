RSpec.describe DistroReleaseComparisonComponent, type: :component do
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
  let(:distro) { base_release.distro }

  before do
    create(:package_version_local, package: create(:package, project: base_project, name: 'cacti'), version: '1.0~rc1')
    create(:package_version_local, package: create(:package, project: target_project, name: 'cacti'), version: '1.0')
    create(:package_version_local, package: create(:package, project: base_project, name: 'bash'), version: '5.2')
  end

  it 'labels the packages with the names of the releases' do
    render_inline(described_class.new(distro: distro, distro_releases: distro.distro_releases,
                                      base_release: base_release, target_release: target_release))

    expect(page).to have_css('tr', text: /cacti.*1\.0~rc1.*1\.0.*Newer in 16\.0/m)
    expect(page).to have_css('tr', text: /bash.*5\.2.*Only in 15\.6/m)
  end

  it 'asks to choose two existing releases when one is missing' do
    render_inline(described_class.new(distro: distro, distro_releases: distro.distro_releases, base_release: base_release))

    expect(page).to have_text("Please choose two existing releases of #{distro.name} to compare.")
  end
end
