require 'rails_helper'

RSpec.describe Feature do
  subject { Feature.active?(:bootstrap) }

  let(:is_beta) { false }

  before do
    allow(YAML).to receive(:load).and_return(yaml)
    Feature.use_beta_features(is_beta)
    Feature.refresh!
  end

  context 'with true test settings' do
    let(:yaml) { { 'test' => { 'features' => { 'bootstrap': true } } } }
    it { is_expected.to be_truthy }
  end

  context 'with false test settings' do
    let(:yaml) { { 'test' => { 'features' => { 'bootstrap': false } } } }
    it { is_expected.to be_falsey }
  end

  context 'with beta users' do
    let(:is_beta) { true }
    let(:yaml) { { 'beta' => { 'features' => { 'bootstrap': true } } } }

    it { is_expected.to be_truthy }

    context 'when the file doesn\'t have "beta" key' do
      let(:yaml) { {} }
      it { is_expected.to be_falsey }
    end
  end
end
