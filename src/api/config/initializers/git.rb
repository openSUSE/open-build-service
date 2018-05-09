module Git
  if File.exist?(File.join(Rails.root, 'last_deploy'))
    COMMIT = File.open(File.join(Rails.root, 'last_deploy'), 'r') { |f| GIT_REVISION = f.gets.chomp }
    LAST_DEPLOYMENT = File.new(File.join(Rails.root, 'last_deploy')).atime
  else
    COMMIT = %x(SHA1=$(git rev-parse --short HEAD 2> /dev/null); if [ $SHA1 ]; then echo $SHA1; else echo 'unknown'; fi).chomp
    LAST_DEPLOYMENT = 'unknown'.freeze
  end
end
