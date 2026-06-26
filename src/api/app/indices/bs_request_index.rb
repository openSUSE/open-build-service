ThinkingSphinx::Index.define :bs_request, with: :real_time do
  indexes comment, description, comments_bodies, reviews_reasons

  has id, as: :bs_request_id, type: :integer
  has updated_at, type: :timestamp
end
