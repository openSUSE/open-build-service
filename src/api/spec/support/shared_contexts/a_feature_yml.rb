RSpec.shared_context 'a feature yml' do
  let(:feature_data) do
    <<~YAML
      production:
        features:
          feature_1: false

      beta:
        features:
          feature_1: true

      rollout:
        features:
          feature_1: true
    YAML
  end

  let(:feature_data_without_beta_and_with_rollout_true) do
    <<~YAML
      rollout:
        features:
          feature_1: true
    YAML
  end

  let(:feature_data_with_beta_true_and_without_rollout) do
    <<~YAML
      beta:
        features:
          feature_1: true
    YAML
  end

  let(:feature_data_with_beta_false_and_rollout_true) do
    <<~YAML
      beta:
        features:
          feature_1: false

      rollout:
        features:
          feature_1: true
    YAML
  end
end
