class ProjectsDatatable < Effective::Datatable
  datatable do
    col(:name, col_class: 'text-word-break-all w-50') do |name|
      content_tag(:a, href: project_show_path(name)) do
        concat(name)
      end
    end
    col(:title, col_class: 'w-50')
  end

  collection do
    Project.all
  end
end
