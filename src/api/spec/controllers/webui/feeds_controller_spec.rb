require 'rails_helper'

RSpec.describe Webui::FeedsController do
  let(:project) { create(:project) }
  let(:commit) { create(:project_log_entry, project: project) }
  let(:old_commit) { create(:project_log_entry, project: project, datetime: 'Tue, 09 Feb 2015') }
  let(:admin_user) { create(:admin_user) }

  describe 'GET commits' do
    it 'assigns @commits' do
      get :commits, params: { project: project, format: 'atom' }
      expect(assigns(:commits)).to eq([commit])
    end

    it 'assigns @project' do
      get :commits, params: { project: project, format: 'atom' }
      expect(assigns(:project)).to eq(project)
    end

    it 'fails if project is not existent' do
      expect do
        get :commits, params: { project: 'DoesNotExist', format: 'atom' }
      end.to raise_error ActiveRecord::RecordNotFound
    end

    it 'renders the rss template' do
      get :commits, params: { project: project, format: 'atom' }
      expect(response).to render_template('webui/feeds/commits')
    end

    it 'honors time parameters' do
      get :commits, params: { project: project, format: 'atom', starting_at: '2015-02-09', ending_at: '2015-02-10' }
      expect(assigns(:commits)).to eq([old_commit])
    end
  end

  describe 'GET news' do
    context 'when having status messages for admins only' do
      context 'and the user checking the messages is the admin' do
        before do
          (1..5).each do |n|
            # Make sure created_at timestamps differ
            travel_to(n.seconds.ago) { create(:status_message, message: "message #{n}", user: admin_user) }
          end

          get :news, params: { project: project, format: 'rss' }
        end

        it 'provides a rss feed' do
          expect(response).to have_http_status(:success)
          expect(assigns(:news).map(&:message)).to match_array(['message 1', 'message 2', 'message 3', 'message 4', 'message 5'])
          expect(response).to render_template('webui/feeds/news')
        end
      end

      context 'and the user checking the messages is not the admin' do
        let(:regular_user) { create(:confirmed_user) }
        let(:status_message) { create(:status_message) }
        let(:status_message_for_admins_only) { create(:status_message, :admins_only) }

        before do
          login regular_user
          status_message
          status_message_for_admins_only
          get :news, params: { project: project, format: 'rss' }
        end

        it 'does not show any message' do
          expect(assigns(:news)).to contain_exactly(status_message)
        end
      end
    end
  end

  describe 'GET latest_updates'

  describe 'GET #notifications' do
    let(:user) { create(:confirmed_user) }
    let(:bs_request) do
      create(:add_maintainer_request, bs_request_actions: [create(:bs_request_action_add_maintainer_role,
                                                                  person_name: user.login, target_project: project)])
    end
    let!(:rss_notification) { create(:rss_notification, subscriber: user, event_type: 'Event::RequestCreate', notifiable: bs_request) }

    context 'with a working token' do
      render_views
      before do
        Configuration.update(obs_url: 'http://localhost')
        user.create_rss_token(executor: user)
        get :notifications, params: { token: user.rss_token.string, format: 'rss' }
      end

      after do
        Configuration.update(obs_url: nil)
      end

      it { expect(assigns(:notifications)).to eq(user.combined_rss_feed_items) }
      it { expect(response).to have_http_status(:success) }
      it { is_expected.to render_template('webui/feeds/notifications') }
      it { expect(response.body).to match(/#{user.login} wants to be maintainer in project #{project}/) }
    end

    context 'with an invalid token' do
      before do
        get :notifications, params: { token: 'faken_token', format: 'rss' }
      end

      it { expect(flash[:error]).to eq('Unknown Token for RSS feed') }
      it { is_expected.to redirect_to(root_url) }
    end
  end
end
