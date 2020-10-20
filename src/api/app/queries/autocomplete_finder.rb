class AutocompleteFinder
  def initialize(relation, search_criteria, limit: 50)
    @relation = relation
    @search_criteria = search_criteria
    @limit = limit
  end
end
