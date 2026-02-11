ThinkingSphinx::Index.define :bs_request, with: :real_time do
  indexes comment, description, comments_bodies, reviews_reasons

  has updated_at, type: :timestamp
end
