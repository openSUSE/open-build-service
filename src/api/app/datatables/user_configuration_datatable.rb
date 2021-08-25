class UserConfigurationDatatable < Datatable
  def_delegator :@view, :user_actions
  def_delegator :@view, :user_with_realname_and_icon

  def view_columns
    @view_columns ||= {
      name: { source: 'User.login' },
      realname: { source: 'User.realname' },
      local_user: { source: 'User.ignore_auth_services', searchable: false },
      state: { source: 'User.state' },
      actions: { searchable: false }
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
        name: user_with_realname_and_icon(record),
        realname: record.realname,
        local_user: record.ignore_auth_services,
        state: record.state,
        actions: user_actions(record)
      }
    end
  end
end
