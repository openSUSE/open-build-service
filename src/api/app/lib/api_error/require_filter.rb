class RequireFilter < APIError
  setup 404, 'This call requires at least one filter, either by user, project or package or states or types or reviewstates'
end
