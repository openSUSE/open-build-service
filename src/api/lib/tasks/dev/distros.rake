# Run with bin/rake dev:test_data:create

namespace :dev do
  namespace :distros do
    desc 'Creates test data for vendors, distros, distro releases, and associated models'
    task data: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      puts 'Creating vendors, distros, distro releases, and associations...'

      # Existing architectures and projects created previously in dev:test_data:create
      x86_64 = Architecture.find_by(name: 'x86_64') || create(:architecture, name: 'x86_64')
      aarch64 = Architecture.find_by(name: 'aarch64') || create(:architecture, name: 'aarch64')
      i586 = Architecture.find_by(name: 'i586') || create(:architecture, name: 'i586')
      archs = [x86_64, aarch64]

      leap_project = Project.find_by(name: 'openSUSE:Leap:15.0')
      sample_repos = Repository.where(name: %w[openSUSE_Tumbleweed snapshot]).to_a

      # Projects for vendors
      opensuse_project = Project.find_by(name: 'openSUSE') || create(:project, name: 'openSUSE')
      suse_project = Project.find_by(name: 'SUSE') || create(:project, name: 'SUSE')
      debian_project = Project.find_by(name: 'Debian') || create(:project, name: 'Debian')
      canonical_project = Project.find_by(name: 'Canonical') || create(:project, name: 'Canonical')

      # openSUSE Vendor and Distros
      opensuse = create(:vendor, name: 'openSUSE', project: opensuse_project, description: 'openSUSE Project', url: 'https://www.opensuse.org')
      leap_repos = leap_project&.repositories&.to_a.presence || sample_repos

      tw = create(:distro, name: 'openSUSE Tumbleweed', vendor: opensuse)
      tw_release = create(:distro_release,
                          name: 'Tumbleweed',
                          distro: tw,
                          architectures: [x86_64, aarch64, i586],
                          repositories: sample_repos)

      leap = create(:distro, name: 'openSUSE Leap', vendor: opensuse)
      leap155 = create(:distro_release,
                       name: 'Leap 15.5',
                       distro: leap,
                       architectures: archs,
                       repositories: leap_repos)
      leap156 = create(:distro_release,
                       name: 'Leap 15.6',
                       distro: leap,
                       architectures: archs,
                       repositories: leap_repos)
      leap160 = create(:distro_release,
                       name: 'Leap 16.0',
                       distro: leap,
                       architectures: archs,
                       repositories: leap_repos)

      # SUSE Vendor and Distros
      suse = create(:vendor, name: 'SUSE', project: suse_project, description: 'SUSE Linux Enterprise', url: 'https://www.suse.com')
      sles = create(:distro, name: 'SUSE Linux Enterprise Server', vendor: suse)
      sles15sp5 = create(:distro_release, name: 'SLES 15 SP5', distro: sles, architectures: archs, repositories: sample_repos)
      sles15sp6 = create(:distro_release, name: 'SLES 15 SP6', distro: sles, architectures: archs, repositories: sample_repos)

      # Debian Vendor and Distros
      debian = create(:vendor, name: 'Debian', project: debian_project, description: 'Debian Project', url: 'https://www.debian.org')
      debian_distro = create(:distro, name: 'Debian GNU/Linux', vendor: debian)
      deb12 = create(:distro_release, name: 'Debian 12', description: 'Codename: bookworm', distro: debian_distro, architectures: archs, repositories: sample_repos)

      # Canonical Vendor and Distros
      canonical = create(:vendor, name: 'Canonical', project: canonical_project, description: 'Canonical Ltd.', url: 'https://canonical.com')
      ubuntu = create(:distro, name: 'Ubuntu', vendor: canonical)
      u2404 = create(:distro_release, name: 'Ubuntu 24.04 LTS', description: 'Codename: noble', distro: ubuntu, architectures: archs, repositories: sample_repos)

      # Distro release lifecycles
      lifecycles = [
        [tw_release, 'General Availability', Date.new(2014, 11, 4), :general_availability],
        [leap155, 'Beta', Date.new(2023, 2, 15), :beta],
        [leap155, 'General Availability', Date.new(2023, 6, 7), :general_availability],
        [leap155, 'End of Life', Date.new(2024, 12, 31), :end_of_life],
        [leap156, 'Beta', Date.new(2024, 3, 13), :beta],
        [leap156, 'Release Candidate', Date.new(2024, 4, 24), :release_candidate],
        [leap156, 'General Availability', Date.new(2024, 6, 12), :general_availability],
        [leap156, 'Maintenance', Date.new(2025, 6, 12), :maintenance],
        [leap156, 'End of Life', Date.new(2025, 12, 31), :end_of_life],
        [leap160, 'Planning', Date.new(2024, 10, 1), :planned],
        [leap160, 'Development', Date.new(2025, 3, 1), :development],
        [leap160, 'Alpha', Date.new(2025, 6, 1), :alpha],
        [leap160, 'Beta', Date.new(2025, 10, 15), :beta],
        [leap160, 'Release Candidate', Date.new(2026, 3, 1), :release_candidate],
        [leap160, 'General Availability', Date.new(2026, 6, 12), :general_availability],
        [sles15sp5, 'General Availability', Date.new(2023, 6, 20), :general_availability],
        [sles15sp5, 'Extended Support', Date.new(2024, 7, 1), :extended_support],
        [sles15sp5, 'End of Life', Date.new(2027, 12, 31), :end_of_life],
        [sles15sp6, 'Beta', Date.new(2024, 3, 20), :beta],
        [sles15sp6, 'Release Candidate', Date.new(2024, 5, 15), :release_candidate],
        [sles15sp6, 'General Availability', Date.new(2024, 6, 25), :general_availability],
        [sles15sp6, 'Maintenance', Date.new(2025, 6, 25), :maintenance],
        [sles15sp6, 'End of Life', Date.new(2028, 6, 30), :end_of_life],
        [deb12, 'Alpha', Date.new(2023, 1, 12), :alpha],
        [deb12, 'Release Candidate', Date.new(2023, 4, 3), :release_candidate],
        [deb12, 'General Availability', Date.new(2023, 6, 10), :general_availability],
        [deb12, 'Deprecated', Date.new(2026, 6, 10), :deprecated],
        [deb12, 'End of Life', Date.new(2028, 6, 30), :end_of_life],
        [u2404, 'Beta', Date.new(2024, 4, 11), :beta],
        [u2404, 'Release Candidate', Date.new(2024, 4, 18), :release_candidate],
        [u2404, 'General Availability', Date.new(2024, 4, 25), :general_availability],
        [u2404, 'Maintenance', Date.new(2027, 4, 25), :maintenance],
        [u2404, 'Extended Support', Date.new(2029, 4, 25), :extended_support],
        [u2404, 'End of Life', Date.new(2034, 4, 25), :end_of_life]
      ]
      lifecycles.each do |release, name, date, status|
        DistroReleaseLifecycle.find_or_initialize_by(distro_release: release, name: name).update!(date: date, status: status)
      end
    end
  end
end
