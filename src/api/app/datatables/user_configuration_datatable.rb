class UserConfigurationDatatable < Datatable
  def_delegator :@view, :user_actions
  def_delegator :@view, :user_name_with_icon

  def view_columns
    @view_columns ||= {
      name: { source: 'User.login', cond: :like },
      local_user: { source: 'User.ignore_auth_services' },
      state: { source: 'User.state', cond: :like }
    }
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    User.list
  end
  # rubocop:enable Naming/AccessorMethodName

  def data
    records.map do |record|
      {
        name: user_name_with_icon(record),
        local_user: record.ignore_auth_services,
        state: record.state,
        actions: user_actions(record)
      }
    end
  end
end
