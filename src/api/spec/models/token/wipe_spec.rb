RSpec.describe Token::Wipe do
  let(:user) { create(:user, login: 'foo') }
  let(:token) { create(:wipe_token, executor: user) }

  describe '#call' do
    context 'successful triggered' do
      subject { token.call(project: 'home:foo', package: 'bar') }

      before do
        allow(Backend::Api::Build::Project).to receive(:wipe_binaries).and_return(true)
      end

      it 'records the current date and time in the triggered_at column' do
        expect { subject }.to(change(token, :triggered_at))
      end
    end

    context 'triggered without success' do
      subject { token.call(project: 'home:foo', package: 'bar') }

      before do
        allow(Backend::Api::Build::Project).to receive(:wipe_binaries).and_raise(Backend::Error, 'something went wrong')
      end

      it 'records the current date and time in the triggered_at column' do
        expect { subject }.to raise_error(Backend::Error).and(change(token, :triggered_at))
      end
    end

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
