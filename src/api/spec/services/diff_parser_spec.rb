RSpec.describe DiffParser, type: :service do
  subject { parser.call }

  let(:content) { file_fixture(file.to_s) }
  let(:parser) { described_class.new(content: content) }

  let(:result) { result_array.map { |line| DiffParser::Line.new(content: line[0], state: line[1], index: line[2], original_index: line[3], changed_index: line[4]) } }

  describe '#call' do
    context 'nil diff' do
      let(:content) { nil }

      let(:result_array) { [] }

      it { expect(subject.lines).to eq(result) }
    end

    context 'empty diff' do
      let(:content) { '' }

      let(:result_array) { [] }

      it { expect(subject.lines).to eq(result) }
    end

    context 'simple diff' do
      let(:file) { 'diff_simple.diff' }

      let(:result_array) do
        [
          ["@@ -1,1 +1,1 @@\n", 'range', 1, nil, nil],
          ["-a\n", 'removed', 2, 1, nil],
          ["+b\n", 'added', 3, nil, 1]
        ]
      end

      it 'parses correctly' do
        expect(subject.lines).to eq(result)
      end
    end

    context 'diff with no newline comments' do
      let(:file) { 'diff_with_no_newline_comments.diff' }

      let(:result_array) do
        [
          ["@@ -1,1 +1,1 @@\n", 'range', 1, nil, nil],
          ["-a\n", 'removed', 2, 1, nil],
          ["\\ No newline at end of file\n", 'comment', 3, nil, nil],
          ["+b\n", 'added', 4, nil, 1],
          ["\\ No newline at end of file\n", 'comment', 5, nil, nil]
        ]
      end

      it 'parses correctly' do
        expect(subject.lines).to eq(result)
      end
    end

    context 'diff with highlights' do
      let(:file) { 'diff_with_highlights.diff' }

      let(:result_array) do
        [
          ["@@ -1,1 +1,1 @@\n", 'range', 1, nil, nil],
          ["-bef<span class=\"inline-diff\">o</span>re\n", 'removed', 2, 1, nil],
          ["+bef<span class=\"inline-diff\">after</span>re\n", 'added', 3, nil, 1]
        ]
      end

      it 'parses correctly' do
        expect(subject.lines).to eq(result)
      end
    end
  end
end
