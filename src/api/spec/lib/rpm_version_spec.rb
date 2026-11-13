RSpec.describe RpmVersion do
  describe '.compare' do
    def compare_all(pairs)
      pairs.keys.index_with { |(left, right)| described_class.compare(left, right) }
    end

    let(:segments) do
      {
        ['0.28.0-1.2', '0.27.0-bp161.1.2'] => 1,
        ['3.3.1+28b6d8afc-1.1', '3.1.5~git9.4914e222d'] => 1,
        ['0.16+git20101114', '0.16+git20101166'] => -1,
        ['1.10', '1.9'] => 1,
        ['1.0', '1.0.1'] => -1,
        ['1.01', '1.1'] => 0,
        ['5.5p1', '5.5p10'] => -1
      }
    end
    let(:releases) do
      {
        ['2.4.1-3.5', '2.4.1-bp161.1.2'] => 0,
        ['0.27.0-bp161.1.2', '0.28.0-1.2'] => -1
      }
    end
    let(:tilde_and_caret) do
      {
        ['1.0~rc1', '1.0'] => -1,
        ['3.1.5~git9.4914e222d', '3.1.5'] => -1,
        ['1.0~rc1', '1.0~rc2'] => -1,
        ['1.0^git1', '1.0'] => 1,
        ['1.0^git1', '1.0.1'] => -1
      }
    end
    let(:missing_and_unparsable) do
      {
        [nil, nil] => 0,
        [nil, '1.0'] => -1,
        ['1.0', ''] => 1,
        ['???', '1.0'] => -1,
        ['???', '!!!'] => 0,
        %w[abc 1] => -1
      }
    end

    it 'compares the numeric and alphabetic segments of the versions' do
      expect(compare_all(segments)).to eq(segments)
    end

    it 'ignores the release' do
      expect(compare_all(releases)).to eq(releases)
    end

    it 'sorts "~" before and "^" after the end of the version' do
      expect(compare_all(tilde_and_caret)).to eq(tilde_and_caret)
    end

    it 'handles missing and unparsable versions' do
      expect(compare_all(missing_and_unparsable)).to eq(missing_and_unparsable)
    end
  end
end
