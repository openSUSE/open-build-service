class MissingAction < APIError
  setup 400, 'The request contains no actions. Submit requests without source changes may have skipped!'
end
