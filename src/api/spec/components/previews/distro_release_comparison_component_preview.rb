class DistroReleaseComparisonComponentPreview < ViewComponent::Preview
  def comparison
    distro = Distro.joins(:distro_releases).group(:id).having('COUNT(distro_releases.id) > 1').last
    base_release, target_release = distro.distro_releases.order(:name).last(2)
    render(DistroReleaseComparisonComponent.new(distro: distro, distro_releases: distro.distro_releases,
                                                base_release: base_release, target_release: target_release))
  end

  def missing_release
    distro = Distro.joins(:distro_releases).last
    render(DistroReleaseComparisonComponent.new(distro: distro, distro_releases: distro.distro_releases,
                                                base_release: distro.distro_releases.first))
  end
end
