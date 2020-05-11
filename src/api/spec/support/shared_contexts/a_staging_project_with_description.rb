RSpec.shared_context 'a staging project with description' do
  let(:staging_project_description) do
    <<-HEREDOC
    requests:
    - {author: iznogood, id: 614459, package: latexila, type: delete}
    - {author: dirkmueller, id: 614471, package: iprutils, type: submit}
    requests_comment: 13492
    splitter_info:
      activated: '2018-06-06 05:33:43.433155'
      group: all
      strategy: {name: none}
    HEREDOC
  end
  let(:staging_h) { create(:project, name: 'openSUSE:Factory:Staging:H', description: staging_project_description) }
end
