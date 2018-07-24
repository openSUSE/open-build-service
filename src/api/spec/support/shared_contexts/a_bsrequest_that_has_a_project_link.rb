RSpec.shared_context 'a BsRequest that has a project link' do
  let(:user) { create(:confirmed_user, login: 'project_link_test_user') }
  let(:base_project) { create(:project_with_package, name: 'Base') }
  let(:project_with_link) { create(:project, name: 'Base:my_project', link_to: base_project) }
  let!(:source_package) { create(:package_with_revisions, project: base_project, name: 'source_package', revision_count: 1) }
  let!(:target_package) { create(:package_with_revisions, project: user.home_project, name: 'target_package') }
  let(:xml) do
    <<-XML.strip_heredoc
      <request>
        <action type="submit">
          <source project="#{project_with_link}" package="#{source_package}"/>
          <target project="#{user.home_project}" package="#{target_package}"/>
          <options>
            <sourceupdate>cleanup</sourceupdate>
          </options>
        </action>
      </request>
    XML
  end

  before do
    login(user)
  end
end

RSpec.shared_context 'when sourceupdate is set to' do
  subject do
    bs_request = BsRequest.new(state: 'new', creator: user)
    bs_request.bs_request_actions.build(
      type: 'submit',
      sourceupdate: sourceupdate_type,
      source_project: project_with_link,
      source_package: source_package,
      target_project: user.home_project,
      target_package: target_package
    )
    bs_request
  end
end
