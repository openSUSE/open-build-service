require 'rails_helper'

RSpec.describe Webui::FeedsController do
  let!(:project) { create(:project) }
  let!(:commit) { create(:project_log_entry, project: project) }
  let!(:old_commit) { create(:project_log_entry, project: project, datetime: 'Tue, 09 Feb 2015') }
  let(:admin_user) { create(:admin_user) }

  describe "GET commits" do
    it "assigns @commits" do
      get :commits, params: { project: project, format: 'atom' }
      expect(assigns(:commits)).to eq([commit])
    end

    it "assigns @project" do
      get :commits, params: { project: project, format: 'atom' }
      expect(assigns(:project)).to eq(project)
    end

    it "fails if project is not existent" do
      expect do
        get :commits, params: { project: 'DoesNotExist', format: 'atom' }
      end.to raise_error ActiveRecord::RecordNotFound
    end

    it "renders the rss template" do
      get :commits, params: { project: project, format: 'atom' }
      expect(response).to render_template("webui/feeds/commits")
    end

    it "honors time parameters" do
      get :commits, params: { project: project, format: 'atom', starting_at: "2015-02-09", ending_at: "2015-02-10" }
      expect(assigns(:commits)).to eq([old_commit])
    end

    it "honors sourceaccess flag" do
      create(:sourceaccess_flag, project: project)

      get :commits, params: { project: project, format: 'atom' }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET news" do
    before do
      (1..5).each do |n|
        create(:status_message, message: "message #{n}", user: admin_user)
        # Make sure created_at timestamps differ
        Timecop.travel(1.second)
      end

      get :news, params: { project: project, format: 'rss' }
    end

    it "provides a rss feed" do
      expect(response).to have_http_status(:success)
      expect(assigns(:news).map(&:message)).to match_array(["message 1", "message 2", "message 3", "message 4", "message 5"])
      expect(response).to render_template("webui/feeds/news")
    end
  end

  describe "GET latest_updates" do
    skip
  end

  describe 'GET #notifications' do
    let(:user) { create(:confirmed_user) }
    let(:payload) {
      { author: "heino", description: "I want this role", number: 1899,
        actions: [{ action_id: 2004, type: "add_role", person: "heino", role: "maintainer", targetproject: user.home_project.to_param }],
        state: "new",
        when: "2017-06-27T10:34:30",
        who: "heino" }
    }
    let!(:rss_notification) { create(:rss_notification, event_payload: payload, subscriber: user, event_type: 'Event::RequestCreate') }

    context 'with a working token' do
      render_views
      before do
        ::Configuration.update(obs_url: 'http://localhost')
        user.create_rss_token
        get :notifications, params: { token: user.rss_token.string, format: 'rss' }
      end
      after do
        ::Configuration.update(obs_url: nil)
      end

      it { expect(assigns(:notifications)).to eq(user.combined_rss_feed_items) }
      it { expect(response).to have_http_status(:success) }
      it { is_expected.to render_template("webui/feeds/notifications") }
      it { expect(response.body).to match(/heino wants to be maintainer in project/) }
    end

    context 'with an invalid token' do
      before do
        get :notifications, params: { token: 'faken_token', format: 'rss' }
      end

      it { expect(flash[:error]).to eq("Unknown Token for RSS feed") }
      it { is_expected.to redirect_to(root_url) }
    end
  end
end
