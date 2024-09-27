RSpec.describe Webui::FeedsController, :vcr do
  let(:project) { create(:project) }
  let(:commit) { create(:project_log_entry, project: project) }
  let(:old_commit) { create(:project_log_entry, project: project, datetime: 'Tue, 09 Feb 2015') }
  let(:admin_user) { create(:admin_user) }

  describe 'GET commits' do
    it 'assigns @commits' do
      get :commits, params: { project: project, format: 'atom' }
      expect(assigns(:commits)).to eq([commit])
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
          expect(assigns(:news).map(&:message)).to contain_exactly('message 1', 'message 2', 'message 3', 'message 4', 'message 5')
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

  describe 'GET #notifications' do
    let(:user) { create(:confirmed_user) }
    let(:bs_request) do
      create(:add_maintainer_request, bs_request_actions: Array.new(1) do
                                                            create(:bs_request_action_add_maintainer_role,
                                                                   person_name: user.login, target_project: project)
                                                          end)
    end
    let!(:rss_notification) { create(:notification_for_request, :rss_notification, subscriber: user, event_type: 'Event::RequestCreate', notifiable: bs_request) }

    context 'with an existing rss secret' do
      render_views
      before do
        Configuration.update(obs_url: 'http://localhost')
        user.regenerate_rss_secret
        get :notifications, params: { secret: user.rss_secret, format: 'rss' }
      end

      after do
        Configuration.update(obs_url: nil)
      end

      it { expect(assigns(:notifications)).to eq(user.combined_rss_feed_items) }
      it { expect(response).to have_http_status(:success) }
      it { is_expected.to render_template('webui/feeds/notifications') }
      it { expect(response.body).to match(/#{user.login} wants to be maintainer in project #{project}/) }
    end

    context 'with an non-existing rss secret' do
      subject { get :notifications, params: { secret: 'fake_secret', format: 'rss' } }

      it 'raises an error' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when fetching build failed notifications' do
      let(:user) { create(:user, :with_home) }
      let(:package) { create(:package, project: user.home_project) }
      let(:event_payload) do
        {
          project: 'project',
          package: 'package',
          repository: 'repo',
          arch: 'arch'
        }
      end
      let!(:notification_build_failure) { create(:notification_for_request, :rss_notification, event_type: 'Event::BuildFail', subscriber: user, notifiable: package, event_payload: event_payload) }

      render_views
      before do
        Configuration.update(obs_url: 'http://localhost')
        user.regenerate_rss_secret
        get :notifications, params: { secret: user.rss_secret, format: 'rss' }
      end

      after do
        Configuration.update(obs_url: nil)
      end

      it { is_expected.to render_template('notifications/build_fail') }
    end

    context 'when fetching relationship create notifications' do
      let(:user) { create(:user, :with_home) }
      let(:package) { create(:package, project: user.home_project) }
      let(:event_payload) do
        {
          package: 'package',
          project: 'project',
          who: 'who',
          role: 'role'
        }
      end
      let!(:notification_relationship_create) { create(:notification_for_request, :rss_notification, event_type: 'Event::RelationshipCreate', subscriber: user, notifiable: package, event_payload: event_payload) }

      render_views
      before do
        Configuration.update(obs_url: 'http://localhost')
        user.regenerate_rss_secret
        get :notifications, params: { secret: user.rss_secret, format: 'rss' }
      end

      after do
        Configuration.update(obs_url: nil)
      end

      it { is_expected.to render_template('notifications/relationship_create') }
    end
  end
end
