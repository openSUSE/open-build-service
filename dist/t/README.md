# Open Build Service Appliance QA Suite
This is a test suite based on perl's [prove](http://perldoc.perl.org/prove.html),
and [RSpec](http://rspec.info/). We are testing the following:

* The appliance boots and all OBS servers start
* Sign Up & Log In via the frontend works
* Building a simple package works

## Running the suite
This test suite runs [automatically](https://github.com/os-autoinst/os-autoinst-distri-obs)
against new appliances that got built from
our [OBS:Server:Unstable](https://build.opensuse.org/project/show/OBS:Server:Unstable)
on [openQA](https://openqa.opensuse.org/).


## QA for package updates
Additionally our [test instance](https://build-test.opensuse.org/) rebuilds all packages in
[OBS:Server:Unstable](https://build.opensuse.org/project/show/OBS:Server:Unstable) and
it's publisher is calling "zypper up" to update itself.
