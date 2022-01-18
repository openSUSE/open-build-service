require 'rails_helper'

RSpec.describe WorkflowRunRowComponent, type: :component do
  let(:workflow_token) { create(:workflow_token) }
  let(:request_headers) do
    <<~END_OF_HEADERS
      HTTP_X_GITHUB_EVENT: pull_request
    END_OF_HEADERS
  end
  let(:workflow_run) do
    create(:workflow_run,
           token: workflow_token,
           request_headers: request_headers,
           request_payload: request_payload)
  end

  before do
    render_inline(described_class.new(workflow_run: workflow_run))
  end

  context 'every single workflow run' do
    let(:request_payload) do
      <<~END_OF_REQUEST
        {
          "pull_request": {
            "url": "https://example.com/pr/1",
            "number": "1"
          },
          "repository": {
            "full_name": "Example Repository",
            "html_url": "https://example.com"
          }
        }
      END_OF_REQUEST
    end

    it 'shows the date the workflow run was created' do
      expect(rendered_component).to have_text(workflow_run.created_at)
    end
  end

  context 'when there is no repository present' do
    let(:request_payload) do
      <<~END_OF_REQUEST
        {
          "pull_request": {
            "url": "https://example.com/pr/1"
          }
        }
      END_OF_REQUEST
    end

    it { expect(rendered_component).to have_text('Unknown source') }
    it { expect(rendered_component).not_to have_link }
  end

  context 'when the workflow comes from a pull request event' do
    let(:request_payload) do
      <<~END_OF_REQUEST
        {
          "pull_request": {
            "url": "https://example.com/pr/1",
            "number": "1"
          },
          "repository": {
            "full_name": "Example Repository",
            "html_url": "https://example.com"
          }
        }
      END_OF_REQUEST
    end

    it { expect(rendered_component).to have_text 'Pull request event' }

    it 'shows a link to the repository' do
      expect(rendered_component).to have_link('Example Repository', href: 'https://example.com')
    end

    it 'shows a link to the pull request' do
      expect(rendered_component).to have_link('#1', href: 'https://example.com/pr/1')
    end

    # TODO: What happens with stuff from GitLab?
    ['closed', 'opened', 'reopened', 'synchronize'].each do |action|
      context "and the action is '#{action}'" do
        let(:request_payload) do
          <<~END_OF_REQUEST
            {
              "action": "#{action}",
              "pull_request": {
                "url": "https://example.com/pr/1",
                "number": "1"
              },
              "repository": {
                "full_name": "Example Repository",
                "html_url": "https://example.com"
              }
            }
          END_OF_REQUEST
        end

        it { expect(rendered_component).to have_text action.humanize }
      end
    end

    context 'and the action is unsupported' do
      let(:request_payload) do
        <<~END_OF_REQUEST
          {
            "action": "edited",
            "pull_request": {
              "url": "https://example.com/pr/1",
              "number": "1"
            },
            "repository": {
              "full_name": "Example Repository",
              "html_url": "https://example.com"
            }
          }
        END_OF_REQUEST
      end

      it 'does not show the action anywhere' do
        expect(rendered_component).to have_text('Unsupported')
      end
    end
  end

  context 'when the workflow comes from a push event' do
    let(:request_headers) do
      <<~END_OF_HEADERS
        HTTP_X_GITHUB_EVENT: push
      END_OF_HEADERS
    end
    let(:request_payload) do
      <<~END_OF_REQUEST
        {
          "head_commit": {
            "id": "1234",
            "url": "https://example.com/commit/1234"
          },
          "repository": {
            "full_name": "Example Repository",
            "html_url": "https://example.com"
          }
        }
      END_OF_REQUEST
    end

    it { expect(rendered_component).to have_text 'Push event' }

    it 'shows a link to the repository' do
      expect(rendered_component).to have_link('Example Repository', href: 'https://example.com')
    end

    it 'shows a link to the pushed commit' do
      expect(rendered_component).to have_link('1234', href: 'https://example.com/commit/1234')
    end
  end

  context 'when the workflow is still running' do
    let(:workflow_run) do
      create(:workflow_run,
             status: 'running',
             token: workflow_token,
             request_headers: request_headers,
             request_payload: request_payload)
    end
    let(:request_payload) { {} }

    it 'shows a green check mark' do
      expect(rendered_component).to have_selector('i', class: 'fas fa-running')
    end
  end

  context 'when the workflow runs successfully' do
    let(:workflow_run) do
      create(:workflow_run,
             status: 'success',
             token: workflow_token,
             request_headers: request_headers,
             request_payload: request_payload)
    end
    let(:request_payload) { {} }

    it 'shows a green check mark' do
      expect(rendered_component).to have_selector('i', class: 'fas fa-check text-primary')
    end
  end

  context 'when the workflow fails' do
    let(:workflow_run) do
      create(:workflow_run,
             status: 'fail',
             token: workflow_token,
             request_headers: request_headers,
             request_payload: request_payload)
    end
    let(:request_payload) { {} }

    it 'shows an exclamation mark' do
      expect(rendered_component).to have_selector('i', class: 'fas fa-exclamation-triangle text-danger')
    end
  end
end
