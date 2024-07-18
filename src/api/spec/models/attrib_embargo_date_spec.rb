RSpec.describe 'Attrib', '#embargo_date' do
  describe '#validate_embargo_date_value' do
    subject { build(:embargo_date_attrib, values: [attrib_value]) }

    before do
      subject.valid?
    end

    context 'wrong date' do
      let(:attrib_value) { build(:attrib_value, value: '2022-01-50') }

      it {
        expect(subject.errors[:embargo_date]).to contain_exactly("Value '2022-01-50' couldn't be parsed: 'argument out of range'")
      }
    end

    context 'wrong timezone' do
      let(:attrib_value) { build(:attrib_value, value: '2022-01-01 12:10 wrong_timezone') }

      it {
        expect(subject.errors[:embargo_date]).to contain_exactly("Value '2022-01-01 12:10 wrong_timezone' contains a non-valid timezone")
      }
    end
  end

  describe '#embargo_date' do
    subject { build(:embargo_date_attrib, project: create(:project), values: [attrib_value]).embargo_date }

    context 'is an empty string' do
      let(:attrib_value) { build(:attrib_value, value: '') }

      it { expect(subject).to be_nil }
    end

    context 'is invalid' do
      let(:attrib_value) { create(:attrib_value, value: 'batatinha') }

      it { expect(subject).to be_nil }
    end

    context 'is valid' do
      let(:attrib_value) { create(:attrib_value, value: '2022-01-01 01:01:01 CET') }

      it { expect(subject).to eql(Time.zone.parse('2022-01-01 01:01:01 CET')) }
    end

    context 'is without time' do
      let(:attrib_value) { create(:attrib_value, value: '2022-01-01') }

      it { expect(subject).to eql(Time.zone.parse('2022-01-01').tomorrow) }
    end
  end
end
