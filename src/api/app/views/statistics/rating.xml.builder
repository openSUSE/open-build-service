
if @package && @project
  xml.rating(@rating[:score],
             :count => @rating[:count], :project => @project, :package => @package,
             :user_score => @rating[:user_score])
elsif @project
  xml.rating(@rating[:score],
             :count => @rating[:count], :project => @project,
             :user_score => @rating[:user_score])
else
  xml.rating
end
