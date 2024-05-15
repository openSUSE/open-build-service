class ProjectDatatable < Datatable
  def_delegator :@view, :link_to
  def_delegator :@view, :project_show_path
  def_delegator :@view, :category_badge
  def_delegator :@view, :safe_join

  def view_columns
    @view_columns ||= {
      name: { source: 'Project.name' },
      title: { source: 'Project.title' }
    }
  end

  def show_all
    @show_all ||= options[:show_all]
  end

  def projects
    @projects ||= options[:projects]
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    if projects
      projects
    else
      show_all ? Project.all : Project.filtered_for_list
    end
  end
  # rubocop:enable Naming/AccessorMethodName

  def data
    records.left_outer_joins(quality_attribs: :values).select('projects.*', 'attrib_values.value AS attrib_value').map do |record|
      {
        name: link_to(record.name, project_show_path(record)) + category_badge(record.attrib_value),
        title: record.title
      }
    end
  end
end
