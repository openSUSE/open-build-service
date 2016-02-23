FactoryGirl.define do
  factory :download_repository do
    arch "x86_64"
    url "http://suse.com"
    repotype "rpmmd"
    repository
  end
end
