RSpec.describe Token::Wipe do
  let(:user) { create(:user, login: 'foo') }
  let(:token) { create(:wipe_token, executor: user) }

  describe '#call' do
    context 'with a package' do
      before do
        allow(Backend::Api::Build::Project).to receive(:wipe_binaries).and_return(true)
        token.call(project: 'home:foo', package: 'bar', repository: 'openSUSE_Tumbleweed', arch: 'x86_64')
      end

      it 'wipes the binaries of the package' do
        expect(Backend::Api::Build::Project).to have_received(:wipe_binaries)
          .with('home:foo', { package: 'bar', repository: 'openSUSE_Tumbleweed', arch: 'x86_64' })
      end
    end

    context 'with a multibuild flavor' do
      before do
        allow(Backend::Api::Build::Project).to receive(:wipe_binaries).and_return(true)
        token.call(project: 'home:foo', package: 'bar', multibuild_flavor: 'flavor')
      end

      it 'wipes the binaries of the flavor' do
        expect(Backend::Api::Build::Project).to have_received(:wipe_binaries).with('home:foo', { package: 'bar:flavor' })
      end
    end

    context 'without a package' do
      before do
        allow(Backend::Api::Build::Project).to receive(:wipe_binaries).and_return(true)
        token.call(project: 'home:foo', repository: 'openSUSE_Tumbleweed')
      end

      it 'wipes the binaries of the project' do
        expect(Backend::Api::Build::Project).to have_received(:wipe_binaries).with('home:foo', { repository: 'openSUSE_Tumbleweed' })
      end
    end
  end
end
