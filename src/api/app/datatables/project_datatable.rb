# NOTE: Folowing: https://github.com/jbox-web/ajax-datatables-rails#using-view-helpers
class ProjectDatatable < AjaxDatatablesRails::ActiveRecord
  extend Forwardable

  def_delegator :@view, :link_to
  def_delegator :@view, :project_show_path

  def initialize(params, opts = {})
    @view = opts[:view_context]
    super
  end

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      name: { source: 'Project.name', cond: :like },
      title: { source: 'Project.title', cond: :like }
    }
  end

  def show_all
    @show_all ||= options[:show_all]
  end

  def projects
    @projects ||= options[:projects]
  end

  def get_raw_records
    if projects
      projects
    else
      show_all ? Project.all : Project.filtered_for_list
    end
  end

  def data
    records.map do |record|
      {
        name: link_to(record.name, project_show_path(record)),
        title: record.title
      }
    end
  end
end
