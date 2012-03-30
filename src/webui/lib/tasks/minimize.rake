require 'tempfile'

# Beware, order matters:
JAVASCRIPT_FILENAMES = [
  'public/javascripts/jquery-1.7.1.min.js',
  'public/javascripts/jquery.expander.min.js',
  'public/javascripts/jquery.flot.min.js',
  'public/javascripts/jquery.flot.stack.min.js',
  #'public/javascripts/jquery.mobile-1.0rc2.min.js',
  'public/javascripts/jquery.tablesorter.js',
  'public/javascripts/jquery.tooltip.min.js',
  'public/javascripts/jquery-ui-1.8.18.custom.min.js',
  'public/javascripts/jrails.js',
  'public/themes/bento/js/script.js',
  'public/javascripts/application.js',
  'public/javascripts/cm2/codemirror.js',
  'public/javascripts/cm2/codemirror-ui-find.js',
  'public/javascripts/cm2/codemirror-ui.js',
  'public/javascripts/cm2/mode/changes.js',
  'public/javascripts/cm2/mode/clike.js',
  'public/javascripts/cm2/mode/clojure.js',
  'public/javascripts/cm2/mode/coffeescript.js',
  'public/javascripts/cm2/mode/css.js',
  'public/javascripts/cm2/mode/diff.js',
  #'public/javascripts/cm2/mode/ecl.js',
  #'public/javascripts/cm2/mode/gfm.js',
  'public/javascripts/cm2/mode/go.js',
  'public/javascripts/cm2/mode/groovy.js',
  'public/javascripts/cm2/mode/haskell.js',
  'public/javascripts/cm2/mode/htmlembedded.js',
  'public/javascripts/cm2/mode/htmlmixed.js',
  'public/javascripts/cm2/mode/javascript.js',
  'public/javascripts/cm2/mode/jinja2.js',
  'public/javascripts/cm2/mode/less.js',
  'public/javascripts/cm2/mode/lua.js',
  'public/javascripts/cm2/mode/markdown.js',
  'public/javascripts/cm2/mode/mysql.js',
  #'public/javascripts/cm2/mode/ntriples.js',
  'public/javascripts/cm2/mode/pascal.js',
  'public/javascripts/cm2/mode/perl.js',
  'public/javascripts/cm2/mode/php.js',
  #'public/javascripts/cm2/mode/plsql.js',
  'public/javascripts/cm2/mode/prjconf.js',
  'public/javascripts/cm2/mode/properties.js',
  'public/javascripts/cm2/mode/python.js',
  'public/javascripts/cm2/mode/r.js',
  'public/javascripts/cm2/mode/rst.js',
  'public/javascripts/cm2/mode/ruby.js',
  #'public/javascripts/cm2/mode/rust.js',
  'public/javascripts/cm2/mode/scheme.js',
  'public/javascripts/cm2/mode/smalltalk.js',
  #'public/javascripts/cm2/mode/sparql.js',
  'public/javascripts/cm2/mode/spec.js',
  #'public/javascripts/cm2/mode/stex.js',
  #'public/javascripts/cm2/mode/tiddlywiki.js',
  #'public/javascripts/cm2/mode/velocity.js',
  #'public/javascripts/cm2/mode/verilog.js',
  'public/javascripts/cm2/mode/xml.js',
  'public/javascripts/cm2/mode/xmlpure.js',
  'public/javascripts/cm2/mode/yaml.js',
]

# Beware, order matters:
CSS_FILENAMES = [
  'public/themes/bento/css/reset.css',
  'public/themes/bento/css/960.css',
  'public/themes/bento/css/base.css',
  #'public/themes/bento/css/base.fluid.fix.css', # We don't use fluid
  #'public/themes/bento/css/grid.css', # Dunno where this is used?
  #'public/themes/bento/css/print.css', # Seems unused
  #'public/themes/bento/css/style.css', # Only includes reset,960,base
  #'public/themes/bento/css/style.fluid.css', # We don't use fluid
  'public/stylesheets/style.css', # OBS global overrides for Bento
  'public/stylesheets/dialog.css',
  'public/stylesheets/monitor.css',
  'public/stylesheets/package.css',
  'public/stylesheets/project.css',
  'public/stylesheets/jquery.tooltip.css',
  'public/stylesheets/cm2/suse.css', # CodeMirror2 OBS styles
  #'public/themes/tumblr-bento/html/style.css',
  #'public/stylesheets/jquery.mobile-1.0rc2.min.css',
  #'public/stylesheets/style.mobile.css',
]

namespace :minimize do

  desc 'Minimize JavaScript with UglifyJS'
  task :js do
    # UglifyJS only accepts one input file, thus put everything into one big blob:
    tmpfile = Tempfile.new('ugly_js')
    JAVASCRIPT_FILENAMES.each do |js_filename|
      puts "Minify JS file '#{js_filename}'"
      File.open(js_filename, 'r') do |js_file|
        js_file.each { |line| tmpfile.write(line) }
      end
    end
    tmpfile.close
    system("uglifyjs -v #{tmpfile.path} > public/javascripts/obs.min.js")
    tmpfile.unlink
  end

  desc 'Minimize CSS'
  task :css do
    require 'rubygems'
    require 'cssmin'
    MINIFIED_CSS_FILENAME = 'public/stylesheets/obs.min.css'

    tmpfile = Tempfile.new('ugly_css')
    CSS_FILENAMES.each do |css_filename|
      puts "Minify CSS file '#{css_filename}'"
      File.open(css_filename, 'r') do |css_file|
        css_file.each do |line|
          # Rewrite CSS url('NOW_WRONG_PATH/image.png'):
          line.gsub!(/url\(['"]?([A-Za-z0-9_\-\/]+\.png)['"]?\)/) do |match|
            save_group = $1 # Will otherwise be overwritten by 'split()'
            # Set new path relative to 'public/' directory:
            "url('/#{File.dirname(css_filename).split('/', 2)[1]}/#{save_group}')"
          end
          tmpfile.write(line)
        end
      end
    end
    tmpfile.close
    File.open(tmpfile.path, 'r') do |tmpfile|
      File.delete(MINIFIED_CSS_FILENAME) if File.exists?(MINIFIED_CSS_FILENAME)
      File.open(MINIFIED_CSS_FILENAME, 'w') do |mincss|
        mincss.puts(CSSMin.minify(tmpfile))
      end
    end
  end

end
