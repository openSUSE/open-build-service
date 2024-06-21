FactoryBot.define do
  factory :binary_release do
    repository
    binary_name { Faker::Lorem.word }
    binary_version { Faker::App.semantic_version }
    binary_release { "150500.#{Faker::App.semantic_version}" }
    binary_arch { Architecture.limit(1).order('RAND()').first.name }
    binary_disturl { "obs://build.opensuse.org/#{Faker::Lorem.word}/#{Faker::Lorem.word}/#{Faker::Crypto.sha1}-#{binary_name}" }
    binary_buildtime { Faker::Time.between(from: 1.year.ago, to: 1.week.ago) }
    binary_releasetime { Faker::Time.between(from: 1.week.ago, to: 1.hour.ago) }
    binary_supportstatus { 'l3' }
    binary_maintainer { "user_#{rand(100)}" }
    binary_id { Faker::Crypto.sha1 }

    trait :modified do
      modify_time { binary_releasetime + 2.days }
      operation { 'modified' }
    end

    trait :obsolete do
      binary_buildtime { Faker::Time.between(from: 2.months.ago, to: 1.month.ago) }
      obsolete_time { 2.weeks.ago }
    end

    trait :on_medium do
      medium { 'SLES15-SP5-Minimal-VM.x86_64-kvm-and-xen-Build5.214.qcow2' }
      # FIXME: Build on_medium association
      binary_cpeid { 'cpe:/o:suse:sle_hpc:15:sp2' }
    end

    trait :update do
      binary_updateinfo { 'SUSE-2014-70' }
      binary_updateinfo_version { '1' }
    end
  end
end
