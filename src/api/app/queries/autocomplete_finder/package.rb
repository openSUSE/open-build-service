class AutocompleteFinder::Package < AutocompleteFinder
  def call
    @relation.where(['lower(packages.name) like lower(?)', "%#{@search_criteria}%"])
             .order(Arel.sql('length(name)'), :name).limit(@limit)
  end
end
