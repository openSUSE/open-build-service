# NOTE: Folowing: https://github.com/jbox-web/ajax-datatables-rails#using-view-helpers
class PackageDatatable < Datatable
  def_delegator :@view, :link_to
  def_delegator :@view, :package_show_path
  def_delegator :@view, :time_ago_in_words

  def initialize(params, opts = {})
    @project = opts[:project]
    super
  end

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'Package.name' },
      changed: { source: 'Package.updated_at', searchable: false }
    }
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    @project.packages.order_by_name
  end
  # rubocop:enable Naming/AccessorMethodName

  def data
    records.map do |record|
      {
        name: link_to(record.name, package_show_path(package: record, project: @project)),
        changed: time_ago_in_words(Time.at(record.updated_at.to_i))
      }
    end
  end
end
