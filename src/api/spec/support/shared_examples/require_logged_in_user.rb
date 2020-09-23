RSpec.shared_examples 'require logged in user' do
  let(:default_opts) { {} }
  let(:opts) { {} }

  subject { process(action, { method: method, **default_opts.merge(opts) }) }

  it 'sets flash error message' do
    subject

    expect(flash[:error]).to eq('Please login to access the requested page.')
  end

  context 'when request is xhr' do
    let(:default_opts) { { xhr: true } }

    it 'returns "Please login" error' do
      subject

      json_response = JSON.parse(response.body)
      expect(json_response).to eq({ 'error' => 'Please login' })
    end
  end

  context 'when proxy_auth_mode == :off' do
    before do
      stub_const('CONFIG', CONFIG.merge('proxy_auth_mode' => :off))
    end

    it { is_expected.to redirect_to(new_session_path) }
  end

  context 'when proxy_auth_mode == :on' do
    before do
      stub_const('CONFIG', CONFIG.merge('proxy_auth_mode' => :on))
    end

    it { is_expected.to redirect_to(root_path) }
  end
end
