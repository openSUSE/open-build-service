# Renders a DistroReleaseComparison with filters by releases and status
class DistroReleaseComparisonComponent < ApplicationComponent
  # Status => CSS class of its badge
  STATUS_CLASSES = {
    newer: 'text-bg-success',
    older: 'text-bg-danger',
    changed: 'text-bg-warning',
    same: 'text-bg-secondary',
    only_in_base: 'text-bg-info',
    only_in_target: 'text-bg-primary'
  }.freeze
  PER_PAGE = 30

  def initialize(distro:, distro_releases:, base_release: nil, target_release: nil, statuses: [], search: nil, page: nil)
    super()

    @distro = distro
    @distro_releases = distro_releases
    @base_release = base_release
    @target_release = target_release
    @comparison = DistroReleaseComparison.new(base_release: base_release, target_release: target_release) if base_release && target_release
    @statuses = DistroReleaseComparison::STATUSES.select { |status| Array(statuses).include?(status.to_s) }
    @search = search.to_s.strip
    @page = page
  end

  private

  delegate :rows, :counts, to: :@comparison

  def filtered_rows
    @filtered_rows ||= rows.select do |row|
      (@statuses.empty? || @statuses.include?(row.status)) && row.package_name.downcase.include?(@search.downcase)
    end
  end

  def paginated_rows
    @paginated_rows ||= Kaminari.paginate_array(filtered_rows).page(@page).per(PER_PAGE)
  end

  def status_label(status)
    {
      newer: "Newer in #{@target_release.name}",
      older: "Newer in #{@base_release.name}",
      changed: 'Changed',
      same: 'Same',
      only_in_base: "Only in #{@base_release.name}",
      only_in_target: "Only in #{@target_release.name}"
    }.fetch(status)
  end

  def compare_path(**query)
    compare_project_distro_releases_path(@distro.project.name, @distro.name, **query)
  end

  def release_path(distro_release)
    project_distro_release_path(@distro.project.name, @distro.name, distro_release.name)
  end
end
