require 'rails_helper'

RSpec.describe Flipper do
  subject { Flipper.enabled?(feature, user) }

  context 'when the feature is enabled for the flipper "beta" group' do
    let(:feature) { :group_feature }

    before do
      Flipper[feature].enable_group(:beta)
    end

    context 'with user in beta' do
      let(:user) { create(:confirmed_user, :in_beta, login: 'Tom') }

      it { expect(subject).to be_truthy }
    end

    context 'with user not in beta' do
      let(:user) { create(:confirmed_user, login: 'Tom') }

      it { expect(subject).to be_falsey }
    end
  end

  context 'when the feature is enabled for the flipper "rollout" group' do
    let(:feature) { :group_feature }

    before do
      Flipper[feature].enable_group(:rollout)
    end

    context 'with user in beta but not in rollout' do
      let(:user) { create(:confirmed_user, :in_beta, in_rollout: false, login: 'Tom') }

      it { expect(subject).to be_falsey }
    end

    context 'with user in rollout but not in beta' do
      let(:user) { create(:confirmed_user, login: 'Tom') }

      it { expect(subject).to be_truthy }
    end

    context 'with user both in beta and rollout' do
      let(:user) { create(:confirmed_user, :in_beta, login: 'Tom') }

      it { expect(subject).to be_truthy }
    end
  end

  context 'without user' do
    let(:user) { nil }
    let(:feature) { :group_feature }

    before do
      Flipper[feature].enable_group(:rollout)
    end

    it { expect(subject).to be_falsey }
  end

  context 'when the feature is global' do
    let(:feature) { :global_feature }

    before do
      Flipper[feature].enable
    end

    context 'with user in rollout' do
      let(:user) { create(:confirmed_user, login: 'Tom') }

      it { expect(subject).to be_truthy }
    end
  end
end
