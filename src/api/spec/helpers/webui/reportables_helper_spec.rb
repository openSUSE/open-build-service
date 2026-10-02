RSpec.describe Webui::ReportablesHelper do
  describe '#link_to_reportables' do
    context 'when reportable is a Comment' do
      let(:author) { create(:confirmed_user, login: 'comment_author') }
      let(:project) { create(:project, name: 'my_project') }
      let(:comment) { create(:comment, commentable: project, user: author, body: 'This is a test comment') }
      let(:report) { create(:report, reportable: comment) }

      it 'links to the target with the comment anchor' do
        result = link_to_reportables(report_id: report.id, reportable_type: 'Comment')
        expect(result).to include("#comment-#{comment.id}")
      end
    end
  end
end
