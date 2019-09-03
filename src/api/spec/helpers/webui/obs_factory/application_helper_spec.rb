require 'rails_helper'

RSpec.describe Webui::ObsFactory::ApplicationHelper, type: :helper do
  describe '#distribution_tests_link' do
    let(:distribution) { ObsFactory::Distribution.new(create(:project, name: 'openSUSE:Leap:15.1')) }

    it 'creates a url to the openqa distribution tests' do
      expect(distribution_tests_url(distribution)).to eq(
        'https://openqa.opensuse.org/tests/overview?distri=opensuse&version=15.1'
      )
    end

    context 'when a version is provided' do
      it 'adds the version to the version to the url' do
        expect(distribution_tests_url(distribution, 'my_version')).to eq(
          'https://openqa.opensuse.org/tests/overview?distri=opensuse&version=15.1&build=my_version'
        )
      end
    end
  end

  describe '#project_bread_crumb' do
    let(:project) { create(:project_with_package) }

    before do
      @project = project.name
    end

    it 'creates a list with a link to projects list' do
      expect(project_bread_crumb).to eq([link_to('Projects', project_list_public_path)])
    end

    context "when it's called with a parameter" do
      it 'adds the content of the parameter to the list' do
        expect(project_bread_crumb('my label')).to eq([link_to('Projects', project_list_public_path), 'my label'])
      end
    end

    context 'when the project has parent projects' do
      let(:child_project) { create(:project_with_package, name: "#{project}:child") }

      before do
        @project = child_project
        @package = project.packages.first.name
      end

      it 'adds a link to the parent projects to the list' do
        expect(project_bread_crumb('Text')).to eq(
          [
            link_to('Projects', project_list_public_path),
            [
              link_to(project, project_show_path(project: project)),
              link_to('child', project_show_path(project: child_project))
            ],
            'Text'
          ]
        )
      end
    end

    context 'when @spider_bot is true' do
      before do
        @spider_bot = true
      end

      it { expect(project_bread_crumb).to be(nil) }
    end
  end
end
