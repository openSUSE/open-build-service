RSpec.describe RpmLintComponent, type: :component do
  subject { RpmLintComponent.new(rpmlint_log_parser: rpmlint_log_parser) }

  let(:rpmlint_log_parser) { instance_double(RpmlintLogParser) }

  before do
    allow(rpmlint_log_parser).to receive_messages(errors: { 'ruby2.5' => 2, 'ruby3.1' => 0 }, warnings: { 'ruby2.5' => 1, 'ruby3.1' => 0 }, info: { 'ruby2.5' => 0, 'ruby3.1' => 0 },
                                                  badness: { 'ruby2.5' => 10, 'ruby3.1' => 0 })
  end

  describe '#issues_chart_data' do
    it 'renders the component' do
      expect(subject.issues_chart_data).to include({ name: 'Errors', data: [['ruby2.5', 2]] },
                                                   { name: 'Warnings', data: { 'ruby2.5' => 1 } },
                                                   { name: 'Info', data: { 'ruby2.5' => 0 } })
    end
  end

  describe '#badness_chart_data' do
    it 'renders the component' do
      expect(subject.badness_chart_data).to include({ name: 'Badness', data: [['ruby2.5', 10]] })
    end
  end
end
