class ProjectDatatable < Datatable
  include Webui::ColorHelper

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

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    options[:projects].left_joins(label_globals: :label_template_global)
                      .includes(label_globals: :label_template_global)
                      .references(:label_globals, :label_template_global).distinct
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

    list = labels.map do |label|
      label_template = label.label_template
      tag.a(href: '#', class: 'label-filter mb-1', data: { label: label_template.name, label_id: label_template.id }) do
        tag.span(label_template.name, class: "badge label-#{label_template.id}",
                                      style: "color: #{contrast_text(label_template.color)}; background-color: #{label_template.color};")
      end
    end
    safe_join(list, ' ')
  end
end
