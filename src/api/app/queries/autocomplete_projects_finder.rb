class AutocompleteProjectsFinder
  def initialize(relation, search_criteria, limit = 50)
    @relation = relation
    @search_criteria = search_criteria
    @limit = limit
  end

  def call
    @relation.where(['lower(name) like lower(?)', "%#{@search_criteria}%"])
             .order(Arel.sql('length(name)'), :name).limit(@limit)
  end
end
