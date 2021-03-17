class MaintenanceIncidentDatatable < Datatable
  def_delegators :@view, :summary_cell, :category_cell, :packages_cell, :info_cell, :release_targets_cell, :build_results_cell, :patchinfo_data

  def initialize(params, opts = {})
    @project = opts[:project]
    super
  end

  def view_columns
    @view_columns ||= {
      summary: { source: 'Project.name', orderable: true },
      category: {},
      packages: {},
      info: {},
      release_targets: {}
    }
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    @project.maintenance_incidents
  end
  # rubocop:enable Naming/AccessorMethodName

  def data
    records.map do |record|
      patchinfo = patchinfo_data(record.patchinfos.first)

      {
        summary: summary_cell(record, patchinfo),
        category: category_cell(record, patchinfo),
        packages: packages_cell(record),
        info: info_cell(record, patchinfo),
        release_targets: release_targets_cell(record)
      }
    end
  end
end
