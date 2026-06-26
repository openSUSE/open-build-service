class CannedResponsesDropdownComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/canned_responses_dropdown_component/preview
  def preview
    canned_responses = CannedResponsePolicy::Scope.new(User.last, CannedResponse).resolve
    render(CannedResponsesDropdownComponent.new(canned_responses))
  end
end
