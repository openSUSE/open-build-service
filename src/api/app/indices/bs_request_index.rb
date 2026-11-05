ThinkingSphinx::Index.define :bs_request, with: :real_time do
  set_property charset_table: '0..9, a..z, _, A..Z->a..z, U+410..U+42F->U+430..U+44F, U+430..U+44F'
  set_property min_infix_len: 3

  indexes comment, description, comments_bodies, reviews_reasons
  indexes source_projects, source_packages, target_projects, target_packages

  has id, as: :bs_request_id, type: :integer
  has updated_at, type: :timestamp
end
