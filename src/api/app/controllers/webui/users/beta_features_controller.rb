class Webui::Users::BetaFeaturesController < Webui::WebuiController
  after_action :verify_policy_scoped

  def index
    @disabled_beta_features = policy_scope(DisabledBetaFeature).pluck(:name)
    @user = User.session
    @beta_features = ENABLED_FEATURE_TOGGLES.reject { |feature_toggle| beta_features_to_reject.include?(feature_toggle[:name].to_s) }
                                            .sort_by { |feature_toggle| feature_toggle[:name] }
  end

  def update
    feature_name = feature_params.keys.first
    feature_action = feature_params.values.first

    if feature_action == 'disable'
      begin
        policy_scope(DisabledBetaFeature).create!(name: feature_name)
        flash[:success] = "You disabled the beta feature '#{feature_name.humanize}'."
      rescue ActiveRecord::RecordInvalid
        flash[:error] = "You already disabled the beta feature '#{feature_name.humanize}'."
      end
    else
      disabled_beta_feature = policy_scope(DisabledBetaFeature).find_by(name: feature_name)
      if disabled_beta_feature && disabled_beta_feature.destroy
        flash[:success] = "You enabled the beta feature '#{feature_name.humanize}'."
      else
        flash[:error] = "You already enabled the beta feature '#{feature_name.humanize}'."
      end
    end

    redirect_to my_beta_features_path
  end

  private

  def feature_params
    params.require(:feature).permit(ENABLED_FEATURE_TOGGLES.pluck(:name))
  end

  # Rolled-out and fully-enabled beta feature cannot be switched, so we do not display them to users
  def beta_features_to_reject
    @beta_features_to_reject ||= begin
      rolled_out_beta_features = Flipper::Adapters::ActiveRecord::Gate.where(key: 'groups', value: 'rollout')
      enabled_beta_features = Flipper::Adapters::ActiveRecord::Gate.where(key: 'boolean', value: 'true')

      rolled_out_beta_features.or(enabled_beta_features).pluck(:feature_key)
    end
  end
end
