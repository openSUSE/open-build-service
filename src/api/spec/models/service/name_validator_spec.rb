require 'webmock/rspec'

RSpec.describe Service::NameValidator do
  it { expect(described_class.new('download_files')).to be_valid }
  it { expect(described_class.new('Foo::Bar')).not_to be_valid }
  it { expect(described_class.new(nil)).not_to be_valid }
end
