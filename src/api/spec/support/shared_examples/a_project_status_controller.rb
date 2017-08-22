RSpec.shared_examples 'a project status controller' do
  it { expect(assigns[:no_project]).to eq('_none_') }
  it { expect(assigns[:all_projects]).to eq('_all_') }
  it { expect(assigns[:current_develproject]).to eq('All Packages') }
  it { expect(assigns[:filter]).to eq('_all_') }
  it { expect(assigns[:ignore_pending]).to be_falsey }
  it { expect(assigns[:limit_to_fails]).to be_truthy }
  it { expect(assigns[:limit_to_old]).to be_falsey }
  it { expect(assigns[:include_versions]).to be_truthy }
  it { expect(assigns[:filter_for_user]).to be_nil }
  it { expect(assigns[:packages]).to eq([]) }
  it { expect(assigns[:develprojects]).to eq(['All Packages', 'No Project']) }
  it { expect(response).to have_http_status(:success) }
end
