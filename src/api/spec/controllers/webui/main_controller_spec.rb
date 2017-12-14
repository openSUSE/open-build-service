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

      expect do
        post :add_news, params: { message: "Some message" }
      end.to_not change(StatusMessage, :count)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq("Please provide a message and severity")

      expect do
        post :add_news, params: { severity: "Green" }
      end.to_not change(StatusMessage, :count)
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

    context "that fails at saving the message" do
      before do
        login(admin_user)
        allow_any_instance_of(StatusMessage).to receive(:save).and_return(false)
        post :add_news, params: { message: "Some message", severity: "Green" }
      end

      it { expect(flash[:error]).not_to be nil }
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

    context "without category param provided" do
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

    context "with category param provided that matches home%" do
      before do
        create(:package, project: admin_user.home_project)
        create_list(:project_with_package, 2)
        get :sitemap_packages, params: { listaction: 'show', category: admin_user.home_project_name }
        @package_paths = Nokogiri::XML(response.body).xpath("//xmlns:loc").map { |url| URI.parse(url).path }
      end

      it "doesn't have packages's urls for non home subprojects" do
        Project.where("name not like 'home:%'").each do |project|
          project.packages.each do |package|
            expect(@package_paths).not_to include("/package/show/#{package.project.name}/#{package.name}")
          end
        end
      end

      it "have packages's urls for home subprojects" do
        Project.where("name like 'home:%'").each do |project|
          project.packages.each do |package|
            expect(@package_paths).to include("/package/show/#{package.project.name}/#{package.name}")
          end
        end
      end
    end

    context "with category param provided as opensuse" do
      before do
        create(:project, name: 'openSUSE')
        create(:project_with_package, name: 'openSUSE:subproject1')
        create(:project_with_package, name: 'openSUSE:subproject2')
        get :sitemap_packages, params: { listaction: 'show', category: 'opensuse' }
        @package_paths = Nokogiri::XML(response.body).xpath("//xmlns:loc").map { |url| URI.parse(url).path }
      end

      it "doesn't have packages's urls for non openSUSE subprojects" do
        Project.where("name not like 'openSUSE:%'").each do |project|
          project.packages.each do |package|
            expect(@package_paths).not_to include("/package/show/#{package.project.name}/#{package.name}")
          end
        end
      end

      it "have packages's urls for openSUSE subprojects" do
        Project.where("name like 'openSUSE:%'").each do |project|
          project.packages.each do |package|
            expect(@package_paths).to include("/package/show/#{package.project.name}/#{package.name}")
          end
        end
      end
    end
  end

  describe "GET #add_news_dialog" do
    before do
      get :add_news_dialog, xhr: true
    end

    it { is_expected.to respond_with(:success) }
  end

  describe "GET #delete_message_dialog" do
    before do
      get :delete_message_dialog, xhr: true
    end

    it { is_expected.to respond_with(:success) }
  end
end
