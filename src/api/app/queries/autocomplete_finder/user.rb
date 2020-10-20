class AutocompleteFinder::User < AutocompleteFinder
  def call
    @relation.where(['lower(login) like lower(?)', "#{@search_criteria}%"])
             .order(Arel.sql('length(login)'), :login).limit(@limit)
  end
end
