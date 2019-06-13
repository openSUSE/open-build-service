require 'rails_helper'

RSpec.describe Feature do
  let(:user) { build(:confirmed_user, :in_beta, login: 'Tom') }
  subject { Feature.active?('bootstrap') }

  context 'with beta users' do
    before do
      allow(User).to receive(:possibly_nobody).and_return(user)
      Feature.instance_variable_set(:@perform_initial_refresh_for_user, true)
    end

    context 'when the file has "beta" key' do
      it { expect(subject).to be_truthy }
    end

    context 'when the file doesn\'t have "beta" key' do
      before do
        allow(YAML).to receive(:load_file).and_return({})
      end

      it { expect(subject).to be_falsey }
    end
  end
end
