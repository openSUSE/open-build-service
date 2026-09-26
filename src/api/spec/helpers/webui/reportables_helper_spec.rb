require 'rails_helper'

RSpec.describe Webui::ReportablesHelper do
  let(:author) { create(:confirmed_user, login: 'comment_author') }
  let(:project) { create(:project, name: 'my_project') }
  let(:package) { create(:package, name: 'my_package', project: project) }
  let(:bs_request) { create(:bs_request) }
  let(:bs_request_action) { create(:bs_request_action, bs_request: bs_request) }
  let(:report_object) { create(:report) }

  describe '#reportable_not_found' do
    it 'returns appropriate message when reportable_type is given' do
      expect(helper.reportable_not_found(reportable_type: 'Comment')).to eq('The reported comment does not exist anymore.')
    end

    it 'returns fallback message when reportable_type is blank' do
      expect(helper.reportable_not_found(reportable_type: '')).to eq('The reported object does not exist anymore.')
    end
  end

  describe '#link_to_reportables' do
    context 'when reportable is blank' do
      it 'returns not found message' do
        report = create(:report)
        report.reportable.destroy! if report.reportable
        expect(helper.link_to_reportables(report_id: report.id, reportable_type: 'Comment')).to eq('The reported comment does not exist anymore.')
      end
    end

    context 'when reportable is a Comment' do
      it 'links to a Project comment' do
        comment = create(:comment, commentable: project, user: author)
        report = create(:report, reportable: comment)
        result = helper.link_to_reportables(report_id: report.id, reportable_type: 'Comment')
        expect(result).to include("/project/show/#{project.name}#comment-#{comment.id}")
        expect(result).to include("Project #{project.name}")
      end

      it 'links to a Package comment' do
        comment = create(:comment, commentable: package, user: author)
        report = create(:report, reportable: comment)
        result = helper.link_to_reportables(report_id: report.id, reportable_type: 'Comment')
        expect(result).to include("/package/show/#{project.name}/#{package.name}#comment-#{comment.id}")
        expect(result).to include("Package #{project.name}/#{package.name}")
      end

      it 'links to a BsRequest comment' do
        comment = create(:comment, commentable: bs_request, user: author)
        report = create(:report, reportable: comment)
        result = helper.link_to_reportables(report_id: report.id, reportable_type: 'Comment')
        expect(result).to include("/request/show/#{bs_request.number}#comment-#{comment.id}")
        expect(result).to include("Request #{bs_request.number}")
      end

      it 'links to a BsRequestAction comment' do
        comment = create(:comment, commentable: bs_request_action, user: author)
        report = create(:report, reportable: comment)
        result = helper.link_to_reportables(report_id: report.id, reportable_type: 'Comment')
        expect(result).to include("/request/show/#{bs_request.number}#comment-#{comment.id}")
        expect(result).to include("request_action_id=#{bs_request_action.id}")
      end

      it 'links to a Report comment' do
        comment = create(:comment, commentable: report_object, user: author)
        report = create(:report, reportable: comment)
        result = helper.link_to_reportables(report_id: report.id, reportable_type: 'Comment')
        expect(result).to include("/reports/#{report_object.id}#comment-#{comment.id}")
        expect(result).to include("Report #{report_object.id}")
      end

      it 'includes host when provided' do
        comment = create(:comment, commentable: project, user: author)
        report = create(:report, reportable: comment)
        result = helper.link_to_reportables(report_id: report.id, reportable_type: 'Comment', host: 'example.com')
        expect(result).to include('http://example.com/project/show/')
      end
    end

    context 'when reportable is a Package' do
      it 'renders link to package' do
        report = create(:report, reportable: package)
        result = helper.link_to_reportables(report_id: report.id, reportable_type: 'Package')
        expect(result).to include("/package/show/#{project.name}/#{package.name}#comments-list")
        expect(result).to include(package.name)
      end
    end

    context 'when reportable is a Project' do
      it 'renders link to project' do
        report = create(:report, reportable: project)
        result = helper.link_to_reportables(report_id: report.id, reportable_type: 'Project')
        expect(result).to include("/project/show/#{project.name}#comments-list")
        expect(result).to include(project.name)
      end
    end

    context 'when reportable is a User' do
      it 'renders link to user' do
        report = create(:report, reportable: author)
        result = helper.link_to_reportables(report_id: report.id, reportable_type: 'User')
        expect(result).to include("/users/#{author.login}")
        expect(result).to include(author.login)
      end
    end

    context 'when reportable is a BsRequest' do
      it 'renders link to request' do
        report = create(:report, reportable: bs_request)
        result = helper.link_to_reportables(report_id: report.id, reportable_type: 'BsRequest')
        expect(result).to include("/request/show/#{bs_request.number}")
        expect(result).to include("Request ##{bs_request.number}")
      end
    end
  end

  describe '#commentable_path' do
    it 'returns path for BsRequest comment' do
      comment = create(:comment, commentable: bs_request, user: author)
      path = helper.commentable_path(comment: comment)
      expect(path).to eq("/request/show/#{bs_request.number}#comment-#{comment.id}")
    end

    it 'returns path for BsRequestAction comment (not in changes)' do
      comment = create(:comment, commentable: bs_request_action, user: author)
      path = helper.commentable_path(comment: comment, in_changes: false)
      expect(path).to include("/request/show/#{bs_request.number}?request_action_id=#{bs_request_action.id}")
      expect(path).to include("#comment-#{comment.id}")
    end

    it 'returns path for BsRequestAction comment (in changes)' do
      comment = create(:comment, commentable: bs_request_action, user: author)
      path = helper.commentable_path(comment: comment, in_changes: true)
      expect(path).to include("/request/changes/#{bs_request.number}")
      expect(path).to include("request_action_id=#{bs_request_action.id}")
    end

    it 'returns path for Package comment' do
      comment = create(:comment, commentable: package, user: author)
      path = helper.commentable_path(comment: comment)
      expect(path).to eq("/package/show/#{project.name}/#{package.name}#comment-#{comment.id}")
    end

    it 'returns path for Project comment' do
      comment = create(:comment, commentable: project, user: author)
      path = helper.commentable_path(comment: comment)
      expect(path).to eq("/project/show/#{project.name}#comment-#{comment.id}")
    end

    it 'returns url for Report comment' do
      comment = create(:comment, commentable: report_object, user: author)
      path = helper.commentable_path(comment: comment)
      expect(path).to include("/reports/#{report_object.id}#comment-#{comment.id}")
    end
  end
end
