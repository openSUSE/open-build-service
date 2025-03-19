# Test class
class TestMultibuildPackage
  include MultibuildPackage
end

RSpec.describe MultibuildPackage do
  let(:test_class) { TestMultibuildPackage }

  context 'class methods' do
    it { expect(test_class).to respond_to(:striping_multibuild_suffix) }

    describe '.striping_multibuild_suffix' do
      context '_patchinfo' do
        subject { test_class.striping_multibuild_suffix('_patchinfo') }

        it { expect(subject).to eq('_patchinfo') }
      end

      context 'multibuild name' do
        subject { test_class.striping_multibuild_suffix('foo:bar') }

        it { expect(subject).to eq('foo') }
      end
    end

    describe '.multibuild_flavor' do
      context '_product' do
        subject { test_class.multibuild_flavor('_product:hans') }

        it { expect(subject).to be_nil }
      end

      context 'no multibuild flavor' do
        subject { test_class.multibuild_flavor('foo') }

        it { expect(subject).to be_nil }
      end

      context 'multibuild flavor' do
        subject { test_class.multibuild_flavor('foo:bar') }

        it { expect(subject).to eq('bar') }
      end
    end
  end

  context 'instance methods' do
    let(:test_class_instance) { TestMultibuildPackage.new }

    let(:multibuild_xml) do
      <<~XML
        <multibuild>
          <flavor>os-autoinst-test</flavor>
        </multibuild>
      XML
    end

    before do
      allow(test_class_instance).to receive_messages(multibuild?: true, source_file: multibuild_xml)
    end

    describe '#multibuild_flavors' do
      subject { test_class_instance.multibuild_flavors }

      it { expect(subject).to include('os-autoinst-test') }
    end

    describe '#multibuild_flavor?' do
      it { expect(test_class_instance).to be_multibuild_flavor('os-autoinst-test') }
      it { expect(test_class_instance).not_to be_multibuild_flavor('nothing-here') }
    end
  end
end
