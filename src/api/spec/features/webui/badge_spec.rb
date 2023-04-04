require 'browser_helper'

RSpec.describe 'Badge', vcr: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:source_project) { user.home_project }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }

  context 'without build results' do
    before do
      path = "#{CONFIG['source_url']}/build/#{user.home_project}/_result?locallink=1&multibuild=1&lastbuild=1" \
             "&package=#{source_package}&view=status"
      stub_request(:get, path).and_return(body:
        %(<resultlist state="eb0459ee3b000176bb3944a67b7c44fa">
          </resultlist>))
    end

    it 'displays the correct unknown state despite percent type' do
      visit project_package_badge_path(source_project.name, source_package.name, format: 'svg', type: 'percent')
      xml = Capybara.string(page.body)
      expect(xml).to have_text('unknown')
    end

    it 'displays the correct unknown state' do
      visit project_package_badge_path(source_project.name, source_package.name, format: 'svg')
      xml = Capybara.string(page.body)
      expect(xml).to have_text('unknown')
    end
  end

  context 'with failing and succeeding build results' do
    before do
      path = "#{CONFIG['source_url']}/build/#{user.home_project}/_result?locallink=1&multibuild=1&lastbuild=1" \
             "&package=#{source_package}&view=status"
      stub_request(:get, path).and_return(body:
        %(<resultlist state="eb0459ee3b000176bb3944a67b7c44fa">
            <result project="home:tom" repository="openSUSE_Leap_42.1" arch="x86_64" code="succeeded" state="building">
              <status package="my_package" code="succeeded" />
            </result>
            <result project="home:tom" repository="images" arch="x86_64" code="failed" state="building">
              <status package="my_package" code="failed" />
            </result>
          </resultlist>))
    end

    it 'displays the correct percentage' do
      visit project_package_badge_path(source_project.name, source_package.name, format: 'svg', type: 'percent')
      xml = Capybara.string(page.body)
      expect(xml).to have_text('50%')
    end

    it 'displays the correct failed state' do
      visit project_package_badge_path(source_project.name, source_package.name, format: 'svg')
      xml = Capybara.string(page.body)
      expect(xml).to have_text('failed')
    end
  end

  context 'with succeeding build results' do
    before do
      path = "#{CONFIG['source_url']}/build/#{user.home_project}/_result?locallink=1&multibuild=1&lastbuild=1" \
             "&package=#{source_package}&view=status"
      stub_request(:get, path).and_return(body:
        %(<resultlist state="eb0459ee3b000176bb3944a67b7c44fa">
            <result project="home:tom" repository="openSUSE_Leap_42.1" arch="x86_64" code="succeeded" state="building">
              <status package="my_package" code="succeeded" />
            </result>
            <result project="home:tom" repository="images" arch="x86_64" code="succeeded" state="building">
              <status package="my_package" code="succeeded" />
            </result>
          </resultlist>))
    end

    it 'displays the correct percentage' do
      visit project_package_badge_path(source_project.name, source_package.name, format: 'svg', type: 'percent')
      xml = Capybara.string(page.body)
      expect(xml).to have_text('100%')
    end

    it 'displays the suceeded state' do
      visit project_package_badge_path(source_project.name, source_package.name, format: 'svg')
      xml = Capybara.string(page.body)
      expect(xml).to have_text('succeeded')
    end
  end
end
