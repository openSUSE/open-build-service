RSpec.describe WorkflowRunFilterComponent, type: :component do
  let(:token_user) { create(:confirmed_user) }
  let(:workflow_token) { create(:workflow_token, executor: token_user) }
  let!(:workflow_run) { create(:workflow_run, token: workflow_token) }

  context 'when having no filters selected' do
    before do
      render_inline(described_class.new(token: workflow_token, selected_filter: {}))
    end

    # rubocop:disable RSpec/ExampleLength
    # rubocop:disable RSpec/MultipleExpectations
    it 'selects no filters' do
      expect(rendered_content).to(have_no_checked_field('success'))
      expect(rendered_content).to(have_no_checked_field('running'))
      expect(rendered_content).to(have_no_checked_field('fail'))
      expect(rendered_content).to(have_no_checked_field('Pull/Merge Request'))
      expect(rendered_content).to(have_no_checked_field('push'))
      expect(rendered_content).to(have_no_checked_field('tag_push'))
    end
    # rubocop:enable RSpec/MultipleExpectations
    # rubocop:enable RSpec/ExampleLength
  end

  context 'when having multiple filters selected' do
    before do
      render_inline(described_class.new(token: workflow_token,
                                        selected_filter: { status: %w[success running],
                                                           event_type: %w[pull_request push],
                                                           request_action: ['opened'],
                                                           pr_mr: '1',
                                                           commit_sha: '' }))
    end

    # rubocop:disable RSpec/ExampleLength
    # rubocop:disable RSpec/MultipleExpectations
    it 'checks the appropriate checkboxes' do
      expect(rendered_content).to have_checked_field('success')
      expect(rendered_content).to have_checked_field('running')
      expect(rendered_content).to(have_no_checked_field('fail'))
      expect(rendered_content).to have_checked_field('pull_request')
      expect(rendered_content).to have_checked_field('push')
      expect(rendered_content).to(have_no_checked_field('tag_push'))
      expect(rendered_content).to have_field('pr_mr', with: '1')
    end
    # rubocop:enable RSpec/MultipleExpectations
    # rubocop:enable RSpec/ExampleLength
  end
end
