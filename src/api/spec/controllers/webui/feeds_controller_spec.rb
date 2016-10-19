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
end
