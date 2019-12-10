require 'rails_helper'

RSpec.describe 'Undelete Package', vcr: true, type: :request do
  let(:user) { create(:confirmed_user, :with_home, login: 'user') }
  let(:package) { create(:package, project: user.home_project, name: 'package') }

  # store it to avoid accessing deleted packages
  let!(:package_source_path) { package.source_path }

  def delete_and_undelete
    api_delete(package_source_path)
    expect(response).to have_http_status(:success)
    api_post(package_source_path, params: { cmd: 'undelete' })
    expect(response).to have_http_status(:success)
    api_get(package_source_path)
    expect(response).to have_http_status(:success)
  end

  before do
    login user
  end

  context 'plain package' do
    it 'can be deleted and undeleted' do
      delete_and_undelete
    end
  end

  context 'patchinfo package' do
    let(:package) { create(:package, project: user.home_project, name: 'patchinfo') }
    let(:patchinfo_xml) do
      <<~XML.strip_heredoc
        <patchinfo incident='123'>
          <category>security</category>
          <issue id='123' tracker='bnc' />
          <rating>moderate</rating>
          <packager>user</packager>
          <description>blah blue
          </description>
          <summary>Security update for someone</summary>
        </patchinfo>
      XML
    end

    before do
      api_put package.source_path('_patchinfo'), params: patchinfo_xml
    end

    it 'can be deleted and undeleted' do
      expect(package).to be_is_patchinfo
      delete_and_undelete
      npackage = user.home_project.packages.find_by(name: 'patchinfo')
      expect(npackage).to be_is_patchinfo
    end
  end
end
