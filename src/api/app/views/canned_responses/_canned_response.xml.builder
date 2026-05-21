builder.canned_response(id: canned_response.id) do |cr|
  cr.title canned_response.title
  cr.content canned_response.content
  cr.user canned_response.user.login
  cr.decision_type canned_response.decision_type if canned_response.decision_type.present?
  cr.created_at canned_response.created_at
  cr.updated_at canned_response.updated_at
end
