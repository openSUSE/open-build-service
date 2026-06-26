class PatchinfoComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/patchinfo_component/preview
  def preview
    patchinfo_action = BsRequestAction.find_by(source_package: 'patchinfo')
    patchinfo_package = Package.find_by_project_and_name(patchinfo_action.source_project, patchinfo_action.source_package)
    patchinfo_text = patchinfo_package.source_file('_patchinfo')
    render(PatchinfoComponent.new(patchinfo_text, request_changes_path(number: patchinfo_action.bs_request.number, request_action_id: patchinfo_action.id)))
  end
end
