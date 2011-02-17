# has_mobile_views

has_mobile_views allows for rendering special versions of views and partials 
for mobile devices. It'll detect those devices using the browser's HTTP_USER_AGENT
string.
The nice thing is that it falls back to the standard views/partials if there's
no dedicated mobile version available.

# Installation
## As a gem
Add the following line to your **config/environment.rb** file:
    config.gem 'has_mobile_views'

## As a plugin
    script/plugin install git://github.com/aduffeck/has_mobile_views.git

# Usage
Just call the **has_mobile_views** class method in the *ApplicationController:*

    class ApplicationController < ActionController::Base
      has_mobile_views
      ...
    end

and create a **app/mobile_views** directory.

Mobile devices will then be served the views from **app/mobile_views** if available, 
e.g.

    app/mobile_views/layouts/application.html.haml

will have precedence over

    app/views/layouts/application.html.haml

# Helpers
has_mobile_views adds a **switch_view_mode_link** helper which will render the
appropriate link to switch to either the normal or the mobile version of your
site, depending on the mode you're currently in.

# TODO
- Test/fix Rails3 support

# Credits
has_mobile_views was created by Andre Duffeck and Thomas Schmidt.
  

Copyright (c) 2011 Andre Duffeck, released under the MIT license
