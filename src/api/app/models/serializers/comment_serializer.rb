module Serializers
  module CommentSerializer
    def to_xml(builder, include_commentable = false)
      attrs = { who: user, when: created_at, id: id }
      if include_commentable
        attrs[commentable.class.name.downcase] = commentable.to_param
        attrs['project'] = commentable.project if commentable.is_a?(Package)
      end
      attrs[:parent] = parent_id if parent_id
      body.delete!("\u0000")

      builder.comment_(attrs) do
        builder.text(body)
      end
    end
  end
end
