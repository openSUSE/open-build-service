RSpec.describe Webui::RpmlintHelper do
  describe '#lint_description' do
    let(:log_with_repeats) do
      <<~LOG
        python311-pkg.noarch: W: files-duplicate /path/to/a /path/to/b
        python312-pkg.noarch: W: files-duplicate /path/to/c /path/to/d
        Your package contains duplicated files that are not hard- or symlinks.
        You should use the %fdupes macro to link the files to one.

        python311-pkg.noarch: W: no-version-in-last-changelog
        The last changelog entry doesn't contain a version.
      LOG
    end

    let(:log_with_special_chars) do
      <<~LOG
        eric.spec: W: no-%check-section
        The spec file does not contain an %check section. Please check if the package
        has a testsuite.
      LOG
    end

    it 'returns the description for a lint appearing multiple times' do
      result = lint_description(lint: 'files-duplicate', content: log_with_repeats)

      expect(result).to include('Your package contains duplicated files')
      expect(result).not_to include('The last changelog entry')
    end

    it 'handles lints with special characters like %' do
      result = lint_description(lint: 'no-%check-section', content: log_with_special_chars)

      expect(result).to eq('The spec file does not contain an %check section. Please check if the package has a testsuite.')
    end

    it 'stops parsing when it hits the next lint' do
      result = lint_description(lint: 'files-duplicate', content: log_with_repeats)

      expect(result).not_to include('no-version-in-last-changelog')
    end

    it 'returns nil if the lint ID is not found' do
      result = lint_description(lint: 'non-existent-lint', content: log_with_repeats)

      expect(result).to be_nil
    end
  end
end
