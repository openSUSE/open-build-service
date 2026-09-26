RSpec.describe Webui::DecisionsController do
  let(:moderator) { create(:moderator) }
  let(:confirmed_user) { create(:confirmed_user) }
  let(:reporter) { create(:confirmed_user) }
  let(:report) { create(:report, reporter: reporter, reason: 'This is spam!') }

  before do
    Flipper.enable(:content_moderation)
  end

  it { is_expected.to use_before_action(:require_login) }
  it { is_expected.to use_after_action(:verify_authorized) }

  describe 'POST #create' do
    let(:decision_params) { { reason: 'This report is legit.', type: 'DecisionFavored', report_ids: [report.id] } }

    context 'when not logged in' do
      before do
        post :create, params: { decision: decision_params }
      end

      it { expect(response).to redirect_to(new_session_path) }
      it { expect(Decision.count).to eq(0) }
    end

    context 'when the content_moderation feature is disabled' do
      before do
        Flipper.disable(:content_moderation)
        login moderator
        request.env['HTTP_REFERER'] = root_url
        post :create, params: { decision: decision_params }
      end

      it { expect(flash[:error]).to eq('Sorry, you are not authorized to create this decision favored.') }
      it { expect(response).to redirect_to(root_url) }
      it { expect(Decision.count).to eq(0) }
    end

    context 'when logged in as a regular user' do
      before do
        login confirmed_user
        request.env['HTTP_REFERER'] = root_url
        post :create, params: { decision: decision_params }
      end

      it { expect(flash[:error]).to eq('Sorry, you are not authorized to create this decision favored.') }
      it { expect(Decision.count).to eq(0) }
    end

    context 'when logged in as a moderator' do
      before { login moderator }

      context 'with a favor decision' do
        before do
          post :create, params: { decision: decision_params }
        end

        it { expect(response).to redirect_to(root_path) }
        it { expect(flash[:success]).to eq('Decision created successfully ') }
        it { expect(Decision.count).to eq(1) }
        it { expect(Decision.last).to be_a(DecisionFavored) }
        it { expect(Decision.last.moderator).to eq(moderator) }
        it { expect(report.reload.decision).to eq(Decision.last) }
      end

      context 'with a cleared decision' do
        before do
          post :create, params: { decision: decision_params.merge(type: 'DecisionCleared') }
        end

        it { expect(flash[:success]).to eq('Decision created successfully ') }
        it { expect(Decision.count).to eq(1) }
        it { expect(Decision.last).to be_a(DecisionCleared) }
      end

      context 'with invalid params' do
        before do
          post :create, params: { decision: decision_params.merge(reason: '') }
        end

        it { expect(flash[:error]).to eq("Reason can't be blank") }
        it { expect(Decision.count).to eq(0) }
      end

      context 'with a decision that creates a delete request' do
        let(:package) { create(:package) }
        let(:report) { create(:report, reportable: package, reporter: reporter, reason: 'This is spam!') }

        before do
          post :create, params: { decision: decision_params.merge(type: 'DecisionFavoredWithDeleteRequest') }
        end

        it { expect(Decision.count).to eq(1) }
        it { expect(Decision.last).to be_a(DecisionFavoredWithDeleteRequest) }
        it { expect(BsRequest.count).to eq(1) }
        it { expect(flash[:success]).to include('Decision created successfully') }
        it { expect(flash[:success]).to include("(request ##{BsRequest.last.number})") }
      end

      context 'with a decision that deletes a package' do
        let(:package) { create(:package) }
        let(:report) { create(:report, reportable: package, reporter: reporter, reason: 'This is spam!') }
        let(:package_deletion_params) { decision_params.merge(type: 'DecisionFavoredWithPackageDeletion') }

        context 'without weak dependencies (devel packages)' do
          before do
            post :create, params: { decision: package_deletion_params }
          end

          it { expect(Decision.count).to eq(1) }
          it { expect(Decision.last).to be_a(DecisionFavoredWithPackageDeletion) }
          it { expect(Package.exists?(package.id)).to be(false) }
          it { expect(flash[:success]).to eq('Decision created successfully ') }
        end

        context 'with weak dependencies (devel packages)' do
          let!(:devel_package) { create(:package, develpackage: package) }

          context 'without force_delete' do
            before do
              post :create, params: { decision: package_deletion_params }
            end

            it { expect(Decision.count).to eq(0) }
            it { expect(Package.exists?(package.id)).to be(true) }
            it { expect(flash[:error]).to eq('The package is used for development, you need to select the force delete option in order to create the decision.') }
            it { expect(response).to redirect_to(report_path(report)) }
          end

          context 'with force_delete' do
            before do
              post :create, params: { force_delete: '1', decision: package_deletion_params }
            end

            it { expect(Decision.count).to eq(1) }
            it { expect(Package.exists?(package.id)).to be(false) }
            it { expect(flash[:success]).to eq('Decision created successfully ') }
          end
        end
      end
    end
  end
end
