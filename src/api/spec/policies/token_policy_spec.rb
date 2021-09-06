require 'rails_helper'

RSpec.describe TokenPolicy do
  let(:token_user) { create(:confirmed_user) }
  let(:user_token) { create(:rebuild_token, user: token_user) }
  let(:other_user) { create(:confirmed_user) }

  let(:workflow_token) { create(:workflow_token, user: token_user) }
  let(:rss_token) { create(:rss_token, user: token_user) }

  subject { described_class }

  permissions :webui_trigger?, :show? do
    it { is_expected.not_to permit(other_user, user_token) }
    it { is_expected.not_to permit(token_user, rss_token) }
    it { is_expected.not_to permit(token_user, workflow_token) }

    it { is_expected.to permit(token_user, user_token) }
  end
end
