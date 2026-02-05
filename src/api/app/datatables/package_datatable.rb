# NOTE: Folowing: https://github.com/jbox-web/ajax-datatables-rails#using-view-helpers
class PackageDatatable < Datatable
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
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'Package.name' },
      version: { source: 'PackageVersion.version', cond: versions_filter },
      labels: { source: 'LabelTemplate.name' },
      changed: { source: 'Package.updated_at', searchable: false }
    }
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    @project.packages.includes(:package_kinds).left_joins(:latest_local_version, :latest_upstream_version, labels: [:label_template]).references(:labels, :label_template)
  end
  # rubocop:enable Naming/AccessorMethodName

  def data
    records.map do |record|
      {
        name: name_with_link(record),
        version: versions_text(record),
        labels: labels_list(record.labels),
        changed: format('%{duration} ago',
                        duration: time_ago_in_words(Time.at(record.updated_at.to_i)))
      }
    end
  end

  def name_with_link(record)
    name = []
    name << link_to(record.name, package_show_path(package: record, project: @project))
    name << link_tag if record.package_kinds.any? { |package_kind| package_kind.kind == 'link' }
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
end
