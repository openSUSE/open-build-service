RSpec.shared_context 'rake' do
  # You define `task` inside your actual test example.
  let(:rake_task) { Rake.application[task] }

  # rubocop:disable RSpec/BeforeAfterAll
  before :all do
    Rake.application = Rake::Application.new
    Rake.application.rake_require(
      self.class.top_level_description,
      [Rails.root.join('lib/tasks').to_s, Rails.root.join('lib/tasks/dev').to_s]
    )
    Rake::Task.define_task(:environment)
  end
  # rubocop:enable RSpec/BeforeAfterAll

  before do
    rake_task.reenable
  end
end
