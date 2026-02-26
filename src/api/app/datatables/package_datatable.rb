# NOTE: Folowing: https://github.com/jbox-web/ajax-datatables-rails#using-view-helpers
class PackageDatatable < Datatable # rubocop:disable Metrics/ClassLength
  include Webui::PackageHelper

  def_delegator :@view, :link_to
  def_delegator :@view, :package_show_path
  def_delegator :@view, :time_ago_in_words
  def_delegator :@view, :tag
  def_delegator :@view, :safe_join

  def initialize(params, opts = {})
    @project = opts[:project]
    super
  end

  def view_columns
    return @view_columns if @view_columns

    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns = {
      name: { source: 'Package.name' },
      labels: { source: 'LabelTemplate.name' },
      changed: { source: 'Package.updated_at', searchable: false }
    }

    @view_columns[:version] = { source: 'PackageVersion.version', cond: versions_filter } if show_version_column?

    @view_columns
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    query = @project.packages.includes(:package_kinds).left_joins(labels: [:label_template]).references(:labels, :label_template)

    if show_version_column?
      local_version_join = <<~SQL.squish
        LEFT JOIN package_versions ON package_versions.id = (
          SELECT id FROM package_versions AS pv_local
          WHERE pv_local.package_id = packages.id AND pv_local.type = 'PackageVersionLocal'
          ORDER BY pv_local.updated_at DESC
          LIMIT 1
        )
      SQL

      upstream_version_join = <<~SQL.squish
        LEFT JOIN package_versions AS latest_upstream_versions_packages ON latest_upstream_versions_packages.id = (
          SELECT id FROM package_versions AS pv_upstream
          WHERE pv_upstream.package_id = packages.id AND pv_upstream.type = 'PackageVersionUpstream'
          ORDER BY pv_upstream.updated_at DESC
          LIMIT 1
        )
      SQL

      query = query.joins(local_version_join).joins(upstream_version_join)
    end

    query
  end
  # rubocop:enable Naming/AccessorMethodName

  def data
    records.map do |record|
      row = {
        name: name_with_link(record),
        labels: labels_list(record.labels),
        changed: format('%{duration} ago',
                        duration: time_ago_in_words(Time.at(record.updated_at.to_i)))
      }

      row[:version] = versions_text(record) if show_version_column?

      row
    end
  end

  def name_with_link(record)
    name = []
    name << link_to(record.name, package_show_path(package: record, project: @project))
    name << link_tag if record.package_kinds.any? { |package_kind| package_kind.kind == 'link' }
    name << scmsync_tag(record) if record.scmsync.present?
    safe_join(name, ' ')
  end

  def labels_list(labels)
    return nil unless labels.any?

    list = labels.map do |label|
      tag.a(href: '#', class: 'label-filter mb-1', data: { label: label.name, label_id: label.id }) do
        tag.span(label.name, class: "badge label-#{label.id}")
      end
    end
    safe_join(list, ' ')
  end

  private

  def link_tag
    tag.span(class: 'badge text-body border') do
      # Using String Concatenation changes the behavior of this line
      # rubocop:disable Style/StringConcatenation
      tag.i(class: 'fas fa-link') + ' Link'
      # rubocop:enable Style/StringConcatenation
    end
  end

  def scmsync_tag(record)
    link_to(record.scmsync, record.scmsync, class: 'ms-1', title: 'Managed in SCM') do
      safe_join([tag.i(class: 'fas fa-code-branch'), ' SCM'])
    end
  end

  def versions_filter
    lambda do |_column, value|
      local = 'package_versions.version'
      upstream = 'latest_upstream_versions_packages.version'

      text = <<~SQL.squish
        CASE
          WHEN #{upstream} IS NULL THEN 'no upstream'
          WHEN #{local} = #{upstream} THEN 'up to date'
          ELSE CONCAT(#{upstream}, ' available')
        END
      SQL

      parenthesized_text = "CONCAT('(', #{text}, ')')"

      ::Arel::Nodes::SqlLiteral.new("CONCAT_WS(' ', #{local}, #{parenthesized_text})").matches("%#{value}%")
    end
  end

  def versions_text(record)
    local = record.latest_local_version&.version
    upstream = record.latest_upstream_version&.version

    # for users in the labels beta program we show
    # different text, since the version state is indicated by labels
    if Flipper.enabled?(:labels, User.session)
      return versions_text_for_users_in_labels_beta(record:, local_version: local, upstream_version: upstream)
    end

    link = if upstream.blank?
             release_monitoring_search_link(record, 'no upstream')
           elsif local == upstream
             release_monitoring_package_link(record, 'up to date')
           else
             release_monitoring_package_link(record, "#{upstream} available")
           end

    parenthesized_text = "(#{link})".html_safe # rubocop:disable Rails/OutputSafety

    ActionController::Base.helpers.safe_join([local, parenthesized_text].compact, ' ')
  end

  def versions_text_for_users_in_labels_beta(record:, local_version:, upstream_version:)
    return if local_version.blank? && upstream_version.blank?

    if upstream_version.blank?
      release_monitoring_search_link(record, local_version)
    elsif local_version == upstream_version
      release_monitoring_package_link(record, local_version)
    else
      release_monitoring_package_link(record, "#{upstream_version} available")
    end
  end

  def show_version_column?
    @show_version_column ||= Flipper.enabled?(:package_version_tracking, User.session) && @project.anitya_distribution_name.present?
  end
end
