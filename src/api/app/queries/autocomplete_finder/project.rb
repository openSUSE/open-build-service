class AutocompleteFinder::Project < AutocompleteFinder
  def call
    @relation.where(['lower(name) like lower(?)', "%#{@search_criteria}%"])
             .order(Arel.sql('length(name)'), :name).limit(@limit)
  end
end
