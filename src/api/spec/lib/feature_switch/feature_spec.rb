require 'rails_helper'

RSpec.describe Feature do
  include_context 'a feature yml'

  before do
    User.session = user
    Feature.instance_variable_set(:@perform_initial_refresh_for_user, true)
    allow(YAML).to receive(:load_file).with("#{Rails.root}/config/feature.yml").and_return(feature_response)
  end

  subject { Feature.active?(:feature_1) }

  context 'with users not in beta and not in rollout' do
    let(:user) { create(:confirmed_user, in_beta: false, in_rollout: false, login: 'Spyke') }
    let(:feature_response) { YAML.safe_load(feature_data) }

    it { expect(subject).to be_falsey }
  end

  context 'with beta users' do
    let(:user) { create(:confirmed_user, :in_beta, in_rollout: false, login: 'Tom') }

    context 'when the file has "beta" key' do
      let(:feature_response) { YAML.safe_load(feature_data) }

      it { expect(subject).to be_truthy }
    end

    context 'when the file doesn\'t have "beta" key' do
      let(:feature_response) { YAML.safe_load(feature_data_without_beta_and_with_rollout_true) }

      it { expect(subject).to be_falsey }
    end
  end

  context 'with users in rollout' do
    let(:user) { create(:confirmed_user, login: 'Jerry') }

    context 'when the file has "rollout" key' do
      let(:feature_response) { YAML.safe_load(feature_data) }

      it { expect(subject).to be_truthy }
    end

    context 'when the file doesn\'t have "rollout" key' do
      let(:feature_response) { YAML.safe_load(feature_data_with_beta_true_and_without_rollout) }

      it { expect(subject).to be_falsey }
    end
  end

  context 'with users in beta and in rollout' do
    let(:user) { create(:confirmed_user, :in_beta, login: 'Tom_Jerry') }
    let(:feature_response) { YAML.safe_load(feature_data_with_beta_false_and_rollout_true) }

    it { expect(subject).to be_truthy }
  end
end
