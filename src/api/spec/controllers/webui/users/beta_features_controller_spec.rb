RSpec.describe Webui::Users::BetaFeaturesController do
  let(:user) { create(:confirmed_user) }

  describe 'when the user is anonymous' do
    before do
      get :index
    end

    it { expect(response).to have_http_status(:found) }
    it { expect(response).to redirect_to(new_session_path) }
  end

  describe 'when the user is logged in' do
    let(:feature_name) { 'labels' }

    before do
      login(user)
      Flipper::Adapters::ActiveRecord::Feature.find_or_create_by(key: feature_name)
    end

    describe 'GET #index' do
      let!(:disabled_feature) { create(:disabled_beta_feature, user: user, name: feature_name) }

      before do
        get :index
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:user)).to eq(user) }
      it { expect(assigns(:disabled_beta_features)).to include('labels') }
      it { expect(assigns(:beta_features)).to include(ENABLED_FEATURE_TOGGLES.first) }

      it 'filters out rolled out features' do
        allow(controller).to receive(:beta_features_to_reject).and_return([ENABLED_FEATURE_TOGGLES.first[:name].to_s])
        get :index
        expect(assigns(:beta_features)).not_to include(ENABLED_FEATURE_TOGGLES.first)
      end
    end

    describe 'PATCH #update' do
      let(:feature_name) { 'labels' }

      context 'when disabling a feature' do
        it 'creates a DisabledBetaFeature and sets success flash' do
          expect {
            patch :update, params: { feature: { feature_name => 'disable' } }
          }.to change(DisabledBetaFeature, :count).by(1)
          expect(flash[:success]).to eq("You disabled the beta feature 'Labels'.")
          expect(response).to redirect_to(my_beta_features_path)
        end

        it 'handles ActiveRecord::RecordInvalid and sets error flash' do
          create(:disabled_beta_feature, user: user, name: feature_name)
          expect {
            patch :update, params: { feature: { feature_name => 'disable' } }
          }.not_to change(DisabledBetaFeature, :count)
          expect(flash[:error]).to eq("You already disabled the beta feature 'Labels'.")
        end
      end

      context 'when enabling a feature' do
        it 'destroys the DisabledBetaFeature and sets success flash' do
          create(:disabled_beta_feature, user: user, name: feature_name)
          expect {
            patch :update, params: { feature: { feature_name => 'enable' } }
          }.to change(DisabledBetaFeature, :count).by(-1)
          expect(flash[:success]).to eq("You enabled the beta feature 'Labels'.")
        end

        it 'sets error flash if the feature was not disabled' do
          expect {
            patch :update, params: { feature: { feature_name => 'enable' } }
          }.not_to change(DisabledBetaFeature, :count)
          expect(flash[:error]).to eq("You already enabled the beta feature 'Labels'.")
        end
      end
    end

    describe '#beta_features_to_reject' do
      it 'rejects rolled out or fully enabled features' do
        relation_double = instance_double(ActiveRecord::Relation)
        allow(Flipper::Adapters::ActiveRecord::Gate).to receive(:where).and_return(relation_double)
        allow(relation_double).to receive(:or).and_return(relation_double)
        allow(relation_double).to receive(:pluck).with(:feature_key).and_return(['rolled_out_feature'])

        get :index
        expect(controller.send(:beta_features_to_reject)).to include('rolled_out_feature')
      end
    end
  end
end
