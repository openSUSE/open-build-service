class ProjectDatatable < AjaxDatatablesRails::ActiveRecord

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      # id: { source: "User.id", cond: :eq },
      # name: { source: "User.name", cond: :like }
      name: { source: "Project.name", cond: :like },
      title: { source: "Project.title", cond: :like },
      description: { source: "Project.description", cond: :like }
    }
  end

  def data
    records.map do |record|
      {
        # example:
        # id: record.id,
        # name: record.name
        name: record.name,
        title: record.title,
        description: record.description
      }
    end
  end

  def get_raw_records
    # insert query here
    # User.all
    Project.all
  end

end
