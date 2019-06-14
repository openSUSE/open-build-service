require 'rails_helper'

RSpec.describe Feature do
  let(:user) { create(:confirmed_user, :in_beta, login: 'Tom') }
  subject { Feature.active?('bootstrap') }

  context 'with beta users' do
    before do
      User.session = user
      Feature.instance_variable_set(:@perform_initial_refresh_for_user, true)
    end

    context 'when the file has "beta" key' do
      it { expect(subject).to be_truthy }

      context 'with bootstrap disable' do
        before do
          allow(YAML).to receive(:load_file).and_return('beta' => { 'features' => { 'bootstrap' => false } })
        end

        it { expect(subject).to be_falsey }
      end
    end

    context 'when the file doesn\'t have "beta" key' do
      before do
        allow(YAML).to receive(:load_file).and_return({})
      end

      it { expect(subject).to be_truthy }
    end
  end
end
