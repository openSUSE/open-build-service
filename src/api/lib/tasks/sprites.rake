namespace :assets do
  desc 'recreate sprite images and css'
  task resprite: :environment do
    require 'sprite_factory'
    SpriteFactory.library = 'chunkypng'
    SpriteFactory.layout = 'packed'
    SpriteFactory.cssurl = "image-url('$IMAGE')" # use a sass-rails helper method to be evaluated by the rails asset pipeline
    ## run it once for the md5sum
    # SpriteFactory.run!('app/assets/icons', output_image: 'tmp/sprite.tmp.png', margin: 2, nocss: true)
    # md5=Digest::MD5.hexdigest(File.open('tmp/sprite.tmp.png').read)
    # File.unlink('tmp/sprite.tmp.png')
    SpriteFactory.run!('app/assets/icons', output_style: 'app/assets/stylesheets/webui/application/icons.scss',
		        output_image: "app/assets/images/icons_sprite.png", margin: 2, nocomments: true) do |images|
	 rules = []
	 images.each do |icon, hash|
	   rules << ".icons-#{icon} { #{hash[:style]}; }"
	 end
	 rules.sort!
	 rules << ".delete-attribute { #{images[:note_delete][:style]} !important; }"
	 rules.join("\n")
    end
    system("optipng", "-o5", "app/assets/images/icons_sprite.png")
  end
end
