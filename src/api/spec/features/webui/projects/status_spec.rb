require 'browser_helper'

RSpec.describe 'ProjectStatus', js: true, vcr: true do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
  let(:project) { user.home_project }
  let(:broken_package_with_error) { create(:package, project: project, name: 'broken_package') }

  let(:repo_for_source_project) do
    repo = create(:repository, name: 'repository_1', project: project, architectures: ['i586'])
    project.store
    repo
  end

  let(:fake_job_history) do
    %(<jobhistlist>
      <jobhist package='#{broken_package_with_error}' rev='1' srcmd5='2ac8bd685591b40e412ee99b182f94c2' versrel='7-3' bcnt='1' readytime='1492687344'
      starttime='1492687470' endtime='1492687507' code='failed' uri='http://127.0.0.1:41355' workerid='vagrant-openSUSE-Leap:1'
      hostarch='x86_64' reason='new build'/>
    </jobhistlist>)
  end

  before do
    login user
    broken_package_with_error
    repo_for_source_project
    path = "#{CONFIG['source_url']}/build/#{user.home_project}/#{repo_for_source_project.name}/i586/_jobhistory?code=lastfailures"
    stub_request(:get, path).and_return(body: fake_job_history)
  end

  it "displays the expected packages in the results' table" do
    visit project_status_path(project_name: project)
    uncheck('limit_to_fails')
    click_button('Filter results')
    expect(find_by_id('status-table')).to have_text('broken_package')
    expect(find_by_id('status-table')).to have_css('.text-danger')
  end
end
