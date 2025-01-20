class ProjectDatatable < Datatable
  def_delegator :@view, :link_to
  def_delegator :@view, :project_show_path
  def_delegator :@view, :category_badge
  def_delegator :@view, :safe_join
  def_delegator :@view, :tag

  def view_columns
    @view_columns ||= {
      name: { source: 'Project.name' },
      labels: { source: 'LabelTemplateGlobal.name' },
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
      projects.left_joins(label_globals: [:label_template_global]).references(:label_globals, :label_template_global).distinct
    elsif show_all
      Project.left_joins(label_globals: [:label_template_global]).references(:label_globals,
                                                                             :label_template_global).distinct
    else
      Project.left_joins(label_globals: [:label_template_global]).references(:label_globals,
                                                                             :label_template_global).filtered_for_list.distinct
    end
  end
  # rubocop:enable Naming/AccessorMethodName

  def data
    records.left_outer_joins(quality_attribs: :values).select('projects.*', 'attrib_values.value AS attrib_value').map do |record|
      {
        name: link_to(record.name, project_show_path(record)) + category_badge(record.attrib_value),
        labels: labels_list(record.label_globals),
        title: record.title
      }
    end
  end

  def labels_list(labels)
    return nil unless labels.any?

    list = labels.map { |label| tag.span(label.name, class: "badge label-#{label.id}", style: "color: #{ApplicationController.helpers.contrast_text(label.color)}; background-color: #{label.color};") }
    safe_join(list, ' ')
  end
end
