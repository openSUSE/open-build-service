require 'rails_helper'

RSpec.describe Backend::ConnectionHelper do
  let(:backend_api_fake_class) do
    extended_class = double("Fake Class with ParsePackageDiff")
    extended_class.extend(Backend::ConnectionHelper)
    extended_class
  end

  context '#calculate_endpoint' do
    subject { backend_api_fake_class }

    context 'with a single string' do
      it { expect(subject.send(:calculate_endpoint, 'single_string')).to eq('single_string')}
    end

    context 'with a template' do
      it { expect(subject.send(:calculate_endpoint, ['string_in_array'])).to eq('string_in_array')}
      it { expect(subject.send(:calculate_endpoint, ['/build/:param', 'my_param'])).to eq('/build/my_param')}
      it { expect(subject.send(:calculate_endpoint, ['/build/:param', 'my param'])).to eq('/build/my%20param')}
      it { expect(subject.send(:calculate_endpoint, ['/build/:param', 'my/param'])).to eq('/build/my/param')}
      it { expect(subject.send(:calculate_endpoint, ['/build/:param', 'my&param'])).to eq('/build/my&param')}
      it { expect(subject.send(:calculate_endpoint, ['/build/:param', 'my?param'])).to eq('/build/my?param')}
      it { expect(subject.send(:calculate_endpoint, ['/build/:param', 'my:param'])).to eq('/build/my:param')}
      it { expect(subject.send(:calculate_endpoint, ['/build/:param', 'my#param'])).to eq('/build/my#param')}
      it { expect(subject.send(:calculate_endpoint, ['/build/:param1/:param2', 'my_param', 'my_2nd_param'])).to eq('/build/my_param/my_2nd_param')}
      it { expect(subject.send(:calculate_endpoint, ['/build/:param1/:param2', 'my_param', 'my_2nd_param'])).to eq('/build/my_param/my_2nd_param')}
      it { expect(subject.send(:calculate_endpoint, ['/build/:param1/:param2', 'home:param2', 'blah'])).to eq('/build/home:param2/blah')}
    end

    context 'with a wrong formed template' do
      it { expect {subject.send(:calculate_endpoint, ['/build/:param'])}.to raise_error(ArgumentError, 'too few arguments')}
    end
  end
end
