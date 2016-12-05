require 'rails_helper'

RSpec.describe Webui::MainController do
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  describe "POST add_news" do
    it "create a status message" do
      login(admin_user)

      post :add_news, params: { message: "Some message", severity: "Green" }
      expect(response).to redirect_to(root_path)
      message = StatusMessage.where(user: admin_user, message: "Some message", severity: "Green")
      expect(message).to exist
    end

    it "requires message and severity parameters" do
      login(admin_user)

      expect {
        post :add_news, params: { message: "Some message" }
      }.to_not change(StatusMessage, :count)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Please provide a message and severity")

      expect {
        post :add_news, params: { severity: "Green" }
      }.to_not change(StatusMessage, :count)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Please provide a message and severity")
    end

    context "non-admin users" do
      before do
        login(user)

        post :add_news, params: { message: "Some message", severity: "Green" }
      end

      it "does not create a status message" do
        expect(response).to redirect_to(root_path)
        message = StatusMessage.where(user: admin_user, message: "Some message", severity: "Green")
        expect(message).not_to exist
      end
    end

    context "empty message" do
      before do
        login(admin_user)
        post :add_news, params: { severity: "Green" }
      end

      it { expect(flash[:error]).to eq("Please provide a message and severity") }
    end

    context "empty severity" do
      before do
        login(admin_user)
        post :add_news, params: { message: "Some message" }
      end

      it { expect(flash[:error]).to eq("Please provide a message and severity") }
    end
  end

  describe "POST delete_message" do
    let(:message) { create(:status_message, user: admin_user) }

    it "marks a message as deleted" do
      login(admin_user)

      post :delete_message, params: { message_id: message.id }
      expect(response).to redirect_to(root_path)
      expect(message.reload.deleted_at).to be_a_kind_of(ActiveSupport::TimeWithZone)
    end

    context "non-admin users" do
      before do
        login(user)
        post :delete_message, params: { message_id: message.id }
      end

      it "can't delete messages" do
        expect(response).to redirect_to(root_path)
        expect(message.reload.deleted_at).to be nil
      end
    end
  end

  describe "GET #sitemap" do
    render_views

    before do
      get :sitemap
      @paths = Nokogiri::XML(response.body).xpath("//xmlns:loc").map do |url|
          uri = URI.parse(url.content)
          "#{uri.path}?#{uri.query}"
      end
    end

    it { expect(@paths).to include('/main/sitemap_projects?') }
    it "have all category's urls" do
      ('a'..'z').to_a.concat(('A'..'Z').to_a).each do |letter|
        expect(@paths).to include("/main/sitemap_packages/show?category=home%3A#{letter}")
      end
    end
    it { expect(@paths).to include("/main/sitemap_packages/show?category=opensuse") }
  end

  describe "GET #sitemap_projects" do
    render_views

    before do
      create(:confirmed_user)
      @projects = create_list(:project, 5)
      get :sitemap_projects
      @project_paths = Nokogiri::XML(response.body).xpath("//xmlns:loc").map { |url| URI.parse(url).path }
    end

    it "have all project's urls" do
      @projects.map(&:name).each do |project_name|
          expect(@project_paths).to include("/project/show/#{project_name}")
      end
    end
  end

  describe "GET #sitemap_packages" do
    render_views

    before do
      create_list(:project_with_package, 5)
      get :sitemap_packages, params: { listaction: 'show' }
      @package_paths = Nokogiri::XML(response.body).xpath("//xmlns:loc").map { |url| URI.parse(url).path }
    end

    it "have all packages's urls" do
      Package.all.each do |package|
          expect(@package_paths).to include("/package/show/#{package.project.name}/#{package.name}")
      end
    end
  end
end
