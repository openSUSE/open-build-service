RSpec.describe Webui::Projects::PulseController do
  let(:project) { create(:project, name: 'pulse_project') }
  let(:package) { create(:package_with_file, name: 'pulse_package', project: project) }
  let(:first_user) { create(:confirmed_user) }
  let(:second_user) { create(:confirmed_user) }

  describe '#show' do
    render_views

    before do
      get :show, format: :html, params: { project_name: project.name }
    end

    it 'load the whole page' do
      expect(response.body).to have_css('#range-header')
      expect(response.body).to have_css('#pulse')
    end

    it 'assigns the correct instance variables' do
      expect(controller.instance_variable_get(:@range)).to eq('week')
      expect(controller.instance_variable_get(:@builds)).to be_nil
    end
  end

  describe '#show async' do
    before do
      10.times do
        Event::BuildSuccess.create(
          project: project.name,
          package: package.name,
          reason: 'build'
        )
      end
      10.times do
        Event::BuildFail.create(
          project: project.name,
          package: package.name,
          reason: 'build'
        )
      end
      10.times do
        Event::CommentForProject.create(
          project: project.name,
          commenter: second_user.id,
          comment_body: "Hey #{first_user.login}, how are you?"
        )
      end

      post :show, format: :js, params: { project_name: project.name, range: 'month' }
    end

    it 'assigns the correct instance variables' do
      expect(controller.instance_variable_get(:@builds).count).to eq(20)
      expect(controller.instance_variable_get(:@comments).count).to eq(10)
    end
  end
end
