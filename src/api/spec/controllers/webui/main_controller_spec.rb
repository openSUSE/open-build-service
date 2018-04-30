require 'rails_helper'

RSpec.describe Webui::MainController do
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  describe 'GET #sitemap' do
    render_views

    before do
      get :sitemap
      @paths = Nokogiri::XML(response.body).xpath('//xmlns:loc').map do |url|
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
    it { expect(@paths).to include('/main/sitemap_packages/show?category=opensuse') }
  end

  describe 'GET #sitemap_projects' do
    render_views

    before do
      create(:confirmed_user)
      @projects = create_list(:project, 5)
      get :sitemap_projects
      @project_paths = Nokogiri::XML(response.body).xpath('//xmlns:loc').map { |url| URI.parse(url).path }
    end

    it "have all project's urls" do
      @projects.map(&:name).each do |project_name|
        expect(@project_paths).to include("/project/show/#{project_name}")
      end
    end
  end

  describe 'GET #sitemap_packages' do
    render_views

    context 'without category param provided' do
      before do
        create_list(:project_with_package, 5)
        get :sitemap_packages, params: { listaction: 'show' }
        @package_paths = Nokogiri::XML(response.body).xpath('//xmlns:loc').map { |url| URI.parse(url).path }
      end

      it "have all packages's urls" do
        Package.all.each do |package|
          expect(@package_paths).to include("/package/show/#{package.project.name}/#{package.name}")
        end
      end
    end

    context 'with category param provided that matches home%' do
      before do
        create(:package, project: admin_user.home_project)
        create_list(:project_with_package, 2)
        get :sitemap_packages, params: { listaction: 'show', category: admin_user.home_project_name }
        @package_paths = Nokogiri::XML(response.body).xpath('//xmlns:loc').map { |url| URI.parse(url).path }
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

    context 'with category param provided as opensuse' do
      before do
        create(:project, name: 'openSUSE')
        create(:project_with_package, name: 'openSUSE:subproject1')
        create(:project_with_package, name: 'openSUSE:subproject2')
        get :sitemap_packages, params: { listaction: 'show', category: 'opensuse' }
        @package_paths = Nokogiri::XML(response.body).xpath('//xmlns:loc').map { |url| URI.parse(url).path }
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
end
