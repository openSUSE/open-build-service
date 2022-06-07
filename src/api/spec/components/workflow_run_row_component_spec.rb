require 'rails_helper'

RSpec.describe WorkflowRunRowComponent, type: :component do
  let(:workflow_token) { create(:workflow_token) }
  let(:request_headers) do
    <<~END_OF_HEADERS
      HTTP_X_GITHUB_EVENT: pull_request
    END_OF_HEADERS
  end
  let(:request_payload) do
    <<~END_OF_REQUEST
      {
      }
    END_OF_REQUEST
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

  context 'when the workflow is triggered via GitHub' do
    context 'and there is no repository present' do
      let(:request_headers) do
        <<~END_OF_HEADERS
          HTTP_X_GITHUB_EVENT: pull_request
        END_OF_HEADERS
      end
      let(:request_payload) do
        <<~END_OF_REQUEST
          {
            "pull_request": {
              "html_url": "https://github.com/zeromq/libzmq/pull/4330",
              "number": 4330
            }
          }
        END_OF_REQUEST
      end

      it { expect(rendered_content).not_to have_link('zeromq/libzmq', href: 'https://github.com/zeromq/libzmq') }
    end

    context 'and comes from a pull request event' do
      let(:request_payload) do
        <<~END_OF_REQUEST
          {
            "action": "opened",
            "pull_request": {
              "html_url": "https://github.com/zeromq/libzmq/pull/4330",
              "number": 4330
            },
            "repository": {
              "full_name": "zeromq/libzmq",
              "html_url": "https://github.com/zeromq/libzmq"
            }
          }
        END_OF_REQUEST
      end

      it { expect(rendered_content).to have_text 'Pull request event' }

      it 'shows a link to the repository' do
        expect(rendered_content).to have_link('zeromq/libzmq', href: 'https://github.com/zeromq/libzmq')
      end

      it 'shows a link to the pull request' do
        expect(rendered_content).to have_link('#4330', href: 'https://github.com/zeromq/libzmq/pull/4330')
      end

      ['closed', 'opened', 'reopened', 'synchronize'].each do |action|
        context "and the action is '#{action}'" do
          let(:request_payload) do
            <<~END_OF_REQUEST
              {
                "action": "#{action}",
                "pull_request": {
                  "html_url": "https://github.com/zeromq/libzmq/pull/4330",
                  "number": 4330
                },
                "repository": {
                  "full_name": "example/repo",
                  "html_url": "https://example.com"
                }
              }
            END_OF_REQUEST
          end

          it { expect(rendered_content).to have_text action.humanize }
        end
      end

      context 'and the action is unsupported' do
        let(:request_payload) do
          <<~END_OF_REQUEST
            {
              "action": "edited",
              "pull_request": {
                "html_url": "https://github.com/zeromq/libzmq/pull/4330",
                "number": 4330
              },
              "repository": {
                "full_name": "example/repo",
                "html_url": "https://example.com"
              }
            }
          END_OF_REQUEST
        end

        it 'does not show the action anywhere' do
          expect(rendered_content).not_to have_text('Unsupported')
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
              "full_name": "example/repo",
              "html_url": "https://example.com"
            }
          }
        END_OF_REQUEST
      end

      it { expect(rendered_content).to have_text 'Push event' }

      it 'shows a link to the repository' do
        expect(rendered_content).to have_link('example/repo', href: 'https://example.com')
      end

      it 'shows a link to the pushed commit' do
        expect(rendered_content).to have_link('1234', href: 'https://example.com/commit/1234')
      end
    end
  end

  context 'when the workflow is triggered via GitLab' do
    let(:request_headers) do
      <<~END_OF_HEADERS
        HTTP_X_GITLAB_EVENT: Merge Request Hook
      END_OF_HEADERS
    end
    let(:request_payload) do
      <<~END_OF_PAYLOAD
        {
          "object_kind": "merge_request",
          "project": {
            "path_with_namespace": "gitlabhq/gitlab-test",
            "web_url":"http://example.com/gitlabhq/gitlab-test"
          },
          "object_attributes": {
            "iid": 1,
            "url": "http://example.com/diaspora/merge_requests/1",
            "action": "open"
          }
        }
      END_OF_PAYLOAD
    end

    context 'when there is no repository present' do
      let(:request_payload) do
        <<~END_OF_PAYLOAD
          {}
        END_OF_PAYLOAD
      end

      it { expect(rendered_content).to have_text('Unknown source') }
      it { expect(rendered_content).not_to have_link('gitlabhq/gitlab-test', href: 'http://example.com/gitlabhq/gitlab-test') }
    end

    context 'and comes from a merge request event' do
      let(:request_headers) do
        <<~END_OF_HEADERS
          HTTP_X_GITLAB_EVENT: Merge Request Hook
        END_OF_HEADERS
      end

      it { expect(rendered_content).to have_text('Merge request hook event') }

      it 'shows a link to the repository' do
        expect(rendered_content).to have_link('gitlabhq/gitlab-test', href: 'http://example.com/gitlabhq/gitlab-test')
      end

      it 'shows a link to the pull request' do
        expect(rendered_content).to have_link('#1', href: 'http://example.com/diaspora/merge_requests/1')
      end

      ['close', 'merge', 'open', 'reopen', 'update'].each do |action|
        context "and the action is '#{action}'" do
          let(:request_payload) do
            <<~END_OF_REQUEST
              {
                "object_attributes":{
                  "action": "#{action}"
                }
              }
            END_OF_REQUEST
          end

          it { expect(rendered_content).to have_text action.humanize }
        end
      end
      context 'and the action is unsupported' do
        let(:request_payload) do
          <<~END_OF_REQUEST
            {
              "object_attributes": {
                "action": "unapproved"
              }
            }
          END_OF_REQUEST
        end

        it 'does not show the action anywhere' do
          expect(rendered_content).not_to have_text('unapproved')
        end
      end
    end

    context 'and comes from a push event' do
      let(:request_headers) do
        <<~END_OF_HEADERS
          HTTP_X_GITLAB_EVENT: Push Hook
        END_OF_HEADERS
      end
      let(:request_payload) do
        <<~END_OF_PAYLOAD
          {
            "event_name":"push",
            "project":{
              "id":27158549,
              "path_with_namespace":"vpereira/hello_world",
              "web_url":"https://gitlab.com/vpereira/hello_world"
            },
            "commits":[
              {
                "id":"3075e06879c6c4bd2ab207b30c5a09d75f825d78",
                "title":"Update workflows.yml",
                "url":"https://gitlab.com/vpereira/hello_world/-/commit/3075e06879c6c4bd2ab207b30c5a09d75f825d78"
              },
              {
                "id":"012c5aa4d0634b384a316046e3122be8dbe44525",
                "title":"Update workflows.yml",
                "url":"https://gitlab.com/vpereira/hello_world/-/commit/012c5aa4d0634b384a316046e3122be8dbe44525"
              },{
                "id":"cff1dafb4e61f958db8ed8697a8e720d1fe3d3e7",
                "title":"Update obs project",
                "url":"https://gitlab.com/vpereira/hello_world/-/commit/cff1dafb4e61f958db8ed8697a8e720d1fe3d3e7"
              }
            ]
          }
        END_OF_PAYLOAD
      end

      it 'shows a link to the repository' do
        expect(rendered_content).to have_link('vpereira/hello_world', href: 'https://gitlab.com/vpereira/hello_world')
      end

      it 'is expected to have text "Push Event"' do
        expect(rendered_content).to have_text('Push hook event')
      end

      it 'shows a link to the pushed commit' do
        expect(rendered_content).to have_link('3075e06879c6c4bd2ab207b30c5a09d75f825d78', href: 'https://gitlab.com/vpereira/hello_world/-/commit/3075e06879c6c4bd2ab207b30c5a09d75f825d78')
      end
    end
  end

  context 'no matter which vendor the workflow comes from' do
    context 'for every single workflow run' do
      it 'shows the date the workflow run was created' do
        expect(rendered_content).to have_text(workflow_run.created_at)
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
        expect(rendered_content).to have_selector('i', class: 'fas fa-running')
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
        expect(rendered_content).to have_selector('i', class: 'fas fa-check text-primary')
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
        expect(rendered_content).to have_selector('i', class: 'fas fa-exclamation-triangle text-danger')
      end
    end

    context 'when the event is something unknown' do
      let(:workflow_run) do
        create(:workflow_run,
               status: 'fail',
               token: workflow_token,
               request_headers: request_headers,
               request_payload: request_payload)
      end
      let(:request_payload) { {} }
      let(:request_headers) do
        <<~END_OF_HEADERS
          HTTP_X_GITHUB_EVENT: fake
        END_OF_HEADERS
      end

      it 'does not blow up' do
        expect(rendered_content).to have_text('Fake event')
      end
    end
  end
end
