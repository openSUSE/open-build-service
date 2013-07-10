xml.comments(:object => @project.name, :object_type => "project", :limit => params[:limit], :offset=> params[:offset]) do
        @comments.each do |msg|
            attrs = {}
            attrs[:id] = msg.id
            attrs[:user] = msg.user
            attrs[:title] = msg.title
            attrs[:parent_id] = msg.parent_id if msg.parent_id
            attrs[:created_at] = msg.created_at
            xml.list(
              msg.body,
              attrs
            )
        end
end