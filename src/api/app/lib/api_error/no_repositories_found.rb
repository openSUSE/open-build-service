class NoRepositoriesFound < APIError
  setup 404, 'No repositories build against target'
end
