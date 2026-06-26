module Git
  if Rails.root.join('last_deploy').exist?
    COMMIT = Rails.root.join('last_deploy').open('r') { |f| f.gets.try(:chomp) }
    LAST_DEPLOYMENT = File.new(Rails.root.join('last_deploy')).mtime
  else
    COMMIT = `SHA1=$(git rev-parse --short HEAD 2> /dev/null); if [ $SHA1 ]; then echo $SHA1; else echo ''; fi`.chomp
    LAST_DEPLOYMENT = ''.freeze
  end
end
