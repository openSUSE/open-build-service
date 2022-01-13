require 'rails_helper'

# Test class
class TestMultibuildPackage
  include MultibuildPackage
end

RSpec.describe MultibuildPackage do
  let(:test_class) { TestMultibuildPackage }

  context 'class methods' do
    it { expect(test_class).to respond_to(:valid_multibuild_name?) }
    it { expect(test_class).to respond_to(:striping_multibuild_suffix) }

    describe '.valid_multibuild_name?' do
      before do
        allow(test_class).to receive(:valid_name?).and_return(package_name_validation)
      end

      context 'valid multibuild name' do
        let(:package_name) { 'foo:bar' }
        let(:package_name_validation) do
          Package.valid_name?(package_name, true)
        end

        subject { test_class.valid_multibuild_name?(package_name) }

        it { expect(subject).to be_truthy }
      end

      context 'invalid multibuild name' do
        let(:package_name) { 'foo:bar' }
        let(:package_name_validation) do
          Package.valid_name?(package_name, false)
        end

        subject { test_class.valid_multibuild_name?(package_name) }

        it { expect(subject).to be_falsey }
      end
    end

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
      allow(test_class_instance).to receive(:multibuild?).and_return(true)
      allow(test_class_instance).to receive(:source_file).and_return(multibuild_xml)
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
