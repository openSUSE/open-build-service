require 'rails_helper'
require 'rantly/rspec_extensions'

RSpec.describe Webui::Packages::BinariesHelper do
  describe '#uploadable?' do
    it { expect(uploadable?('image.raw.xz', 'x86_64')).to be_truthy }
    it { expect(uploadable?('image.vhdfixed.xz', 'x86_64')).to be_truthy }
    it { expect(uploadable?('image.vhdfixed.xz', 'i386')).to be_falsy }
    it { expect(uploadable?('apache2.rpm', 'x86_64')).to be_falsy }
  end
end
