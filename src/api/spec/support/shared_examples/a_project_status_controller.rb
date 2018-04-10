# frozen_string_literal: true
RSpec.shared_examples 'a project status controller' do
  it 'assigns the instance variables' do
    expect(assigns[:no_project]).to eq('_none_')
    expect(assigns[:all_projects]).to eq('_all_')
    expect(assigns[:current_develproject]).to eq('All Packages')
    expect(assigns[:filter]).to eq('_all_')
    expect(assigns[:ignore_pending]).to be_falsey
    expect(assigns[:limit_to_fails]).to be_truthy
    expect(assigns[:limit_to_old]).to be_falsey
    expect(assigns[:include_versions]).to be_truthy
    expect(assigns[:filter_for_user]).to be_nil
    expect(assigns[:packages]).to eq([])
    expect(assigns[:develprojects]).to eq(['All Packages', 'No Project'])
    expect(response).to have_http_status(:success)
  end
end
