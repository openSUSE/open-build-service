FactoryBot.define do
  factory :binary_release do
    binary_arch { 'aarch64' }
    binary_buildtime { '2021-12-29 17:16:30 +0000' }
    binary_disturl { '/foo/bar' }
    binary_name { 'foo' }
    binary_supportstatus { 'bar' }
    binary_id { '31337' }
    binary_version { '0' }
    binary_release { '0' }
    repository { repository }
    flavor { 'bar' }
  end
end
