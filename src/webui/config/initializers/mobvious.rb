Mobvious.configure do |config|
  config.strategies = [
    Mobvious::Strategies::Cookie.new([:mobile, :desktop]),
    Mobvious::Strategies::MobileESP.new(:mobile_desktop)
  ]
end
