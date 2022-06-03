require 'rails_helper'

RSpec.describe WorkflowRunHeaderComponent, type: :component do
  let(:workflow_token) { create(:workflow_token) }
  let(:workflow_run) do
    create(:workflow_run,
           token: workflow_token,
           request_headers: request_headers,
           request_payload: request_payload)
  end

  before do
    render_inline(described_class.new(workflow_run: workflow_run))
  end

  context 'when the workflow comes via GitHub' do
    let(:request_headers) do
      <<~END_OF_HEADERS
        HTTP_X_GITHUB_EVENT: fake
      END_OF_HEADERS
    end
    let(:request_payload) do
      <<~END_OF_REQUEST
        {
          "repository": {
            "full_name": "zeromq/libzmq",
            "html_url": "https://github.com/zeromq/libzmq"
          }
        }
      END_OF_REQUEST
    end

    it 'shows the event as a title' do
      expect(rendered_content).to have_text('Fake event')
    end

    it 'shows the status' do
      expect(rendered_content).to have_text('Running')
    end

    it 'shows the repository' do
      expect(rendered_content).to have_link('zeromq/libzmq', href: 'https://github.com/zeromq/libzmq')
    end

    context 'and it comes from a pull request' do
      let(:request_headers) do
        <<~END_OF_HEADERS
          HTTP_X_GITHUB_EVENT: pull_request
        END_OF_HEADERS
      end

      context 'and has an action' do
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

        it 'shows the action' do
          expect(rendered_content).to have_text('Opened')
        end

        it 'shows a link to the PR' do
          expect(rendered_content).to have_link('#4330', href: 'https://github.com/zeromq/libzmq/pull/4330')
        end

        it 'shows a link to the repository' do
          expect(rendered_content).to have_link('zeromq/libzmq', href: 'https://github.com/zeromq/libzmq')
        end
      end

      context 'but does not have a supported action' do
        let(:request_payload) do
          <<~END_OF_REQUEST
            {
              "action": "edit",
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

        it 'does not show the action' do
          expect(rendered_content).not_to have_text('edit')
        end

        it 'shows a link to the PR' do
          expect(rendered_content).to have_link('#4330', href: 'https://github.com/zeromq/libzmq/pull/4330')
        end

        it 'shows a link to the repository' do
          expect(rendered_content).to have_link('zeromq/libzmq', href: 'https://github.com/zeromq/libzmq')
        end
      end
    end

    context 'and it comes from a push' do
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
              "full_name": "foo/bar",
              "html_url": "https://example.com"
            }
          }
        END_OF_REQUEST
      end

      it 'shows a link to the commit diff' do
        expect(rendered_content).to have_link('1234', href: 'https://example.com/commit/1234')
      end
    end
  end

  context 'when the workflow comes via GitLab' do
    let(:request_headers) do
      <<~END_OF_HEADERS
        HTTP_X_GITLAB_EVENT: Fake Hook
      END_OF_HEADERS
    end
    let(:request_payload) do
      <<~END_OF_PAYLOAD
        {
          "event_name":"push",
          "project": {
            "path_with_namespace": "vpereira/hello_world",
            "web_url":"https://gitlab.com/vpereira/hello_world"
          }
        }
      END_OF_PAYLOAD
    end

    it 'shows the event as a title' do
      expect(rendered_content).to have_text('Fake hook event')
    end

    it 'shows the status' do
      expect(rendered_content).to have_text('Running')
    end

    it 'shows the repository' do
      expect(rendered_content).to have_link('vpereira/hello_world', href: 'https://gitlab.com/vpereira/hello_world')
    end

    context 'when the workflow comes from a merge request' do
      let(:request_headers) do
        <<~END_OF_HEADERS
          HTTP_X_GITLAB_EVENT: Merge Request Hook
        END_OF_HEADERS
      end
      let(:request_payload) do
        <<~END_OF_REQUEST
          {
            "object_attributes":{
              "iid": 1,
              "url": "http://example.com/diaspora/merge_requests/1"
            },
            "project": {
              "path_with_namespace": "gitlabhq/gitlab-test",
              "web_url":"http://example.com/gitlabhq/gitlab-test"
            }
          }
        END_OF_REQUEST
      end

      ['close', 'merge', 'open', 'reopen', 'update'].each do |action|
        context "and has an #{action}" do
          let(:request_payload) do
            <<~END_OF_REQUEST
              {
                "object_attributes":{
                  "url": "http://example.com/diaspora/merge_requests/1",
                  "action": "#{action}"
                },
                "project": {
                  "path_with_namespace": "gitlabhq/gitlab-test",
                  "web_url":"http://example.com/gitlabhq/gitlab-test"
                }
              }
            END_OF_REQUEST
          end

          it "shows the #{action}" do
            expect(rendered_content).to have_text(action.humanize)
          end
        end
      end

      context 'but does not have a supported action' do
        let(:request_payload) do
          <<~END_OF_REQUEST
            {
              "object_attributes":{
                "iid": 1,
                "url": "http://example.com/diaspora/merge_requests/1",
                "action": "unapproved"
              },
              "project": {
                "path_with_namespace": "gitlabhq/gitlab-test",
                "web_url":"http://example.com/gitlabhq/gitlab-test"
              }
            }
          END_OF_REQUEST
        end

        it 'does not show the action' do
          expect(rendered_content).not_to have_text('unapproved')
        end
      end

      it 'shows a link to the MR' do
        expect(rendered_content).to have_link('#1', href: 'http://example.com/diaspora/merge_requests/1')
      end

      it 'shows a link to the repository' do
        expect(rendered_content).to have_link('gitlabhq/gitlab-test', href: 'http://example.com/gitlabhq/gitlab-test')
      end
    end

    context 'and it comes from a push' do
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
              "web_url":"http://gitlab.com:vpereira/hello_world"
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

      it 'shows a link to the commit diff' do
        expect(rendered_content).to have_link('3075e06879c6c4bd2ab207b30c5a09d75f825d78',
                                              href: 'https://gitlab.com/vpereira/hello_world/-/commit/3075e06879c6c4bd2ab207b30c5a09d75f825d78')
      end
    end
  end
end
