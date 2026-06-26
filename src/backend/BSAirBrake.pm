package BSAirBrake;

our $VERSION = '0.0.1';

use strict;
use warnings;
use Data::Dumper;
use JSON::XS ();
use Carp ();
use BSRPC qw/:https/;
use BSUtil;

=head1 NAME

 BSAirBrake - Airbrake Notifier API V3 Client for OBS

=head1 SYNOPSIS

 use BSAirBrake;

 my $ab = BSAirBrake->new(
   server => 'http://yourerrbit.server',
   api_key => 'xyz'
 );

 # sending notify with backtrace and no additional options
 my $error     = "Hello World from BSAirBrake";
 $ab->notify($error, undef, $backtrace);

 # Sending multiple error messages with more information
 # at once
 my $options   = {
   environment => { SCRIPT => $0 },
   session     => { 'session-id' => uuid() },
   params      => { 'param1' => 'value1' },
 };

 my $backtrace =1;

 my $skip_frames = 3; # for backtrace - default is 2

 $self->add_error("Error 1", $backtrace, $skip_frames);

 $self->add_error("Error 2", $backtrace, $skip_frames);

 $self->send($options);

=head1 DESCRIPTION

=head1 METHODS

=head2 new - create new object

 Example:
  my $ab = BSAirBrake->new(
   server => 'http://yourerrbit.server'.
   api_key => 'xyz'
  );

=cut

sub new {
  my ($class, %opt) = @_;

  my $self  = {
      content => {
	errors        => [],
	context       => {
	  os          => $^O,
	  language    => '',
          environment => 'development'
	},
	notifier    => {
	  name    => 'BSAirBrake',
	  version => $VERSION,
	  url     => 'https://github.com/openSUSE/open-build-service.git'
	},
	session     => {},
	environment => {},
	params      => {},
      },
      project_id   => 1,
      server       => '',
      skip_frames  => 2,
      %opt
  };
  return bless $self, $class;
}

=head2 add_error - add error message to send later

 Example:

  $self->add_error("Error 2", $backtrace, $skip_frames);

=cut

sub add_error {
  my ($self, $error, $backtrace, $skip_frames) = @_;

  $error = { message => $error, type => 'error' } unless ref($error);
  die "Unknown error input. Only String or HashRef allowed!\n" if ref($error) ne 'HASH';

  my @bt;
  if ($backtrace) {
    $skip_frames = $self->{skip_frames} unless defined $skip_frames;
    my $i = $skip_frames;
    while (my $ci = Carp::caller_info($i)) {
      unshift @bt, { file => $ci->{file}, line => $ci->{line}, function => $ci->{sub} };
      $i++;
    }
  }
  $error->{backtrace} = \@bt;
  push @{$self->{content}->{errors}}, $error;
}

=head2 send - send queued messages to Airbrake host

 Example:

  $ab->send();

=cut

sub send {
  my ($self, $opt) = @_;
  my $content      = { %{$self->{content}} };
  my $debuglevel   = BSUtil::getdebuglevel();

  $opt ||= {};
  $content->{context}     = $opt->{context}     || $content->{context};
  $content->{environment} = $opt->{environment} || $content->{environment};
  $content->{session}     = $opt->{session}     || $content->{session};
  $content->{params}      = $opt->{params}      || $content->{params};

  die "No airbrake server given\n" unless $self->{server};
  die "No api_key given\n"  unless $self->{api_key};

  $self->{server}  =~ s#/$##;

  my $uri  = "$self->{server}/api/v3/projects/$self->{project_id}/notices";
  my $data = encode_json($content);

  if ($debuglevel >= 7) {
    BSUtil::printlog("Sending POST request to '$uri'", 7);
    BSUtil::printlog("data: $data", 7);
  }

  my $param = {
    uri => $uri,
    request => 'POST',
    data    => JSON::XS::encode_json($self->{content}),
    header  => ["Content-Type: application/json"],
    timeout => exists($opt->{'timeout'}) ? $opt->{'timeout'} : $self->{timeout},
    verbose => $debuglevel,
  };
  my $response = BSRPC::rpc($param, undef, "key=$self->{api_key}");

  if ($debuglevel >= 7) {
    BSUtil::printlog(__PACKAGE__." - received response:", 7);
    BSUtil::printlog($response, 7);
  }

  # Cleanup already sent content
  $self->{content}->{errors}      = [];
  return JSON::XS::decode_json($response);
}

=head2 notify - add_error and send in one step

 Example:

  $ab->notify("My single error message", $options, $backtrace);

=cut

sub notify {
  my ($self, $error, $opt, $backtrace) = @_;

  $self->add_error($error, $backtrace);
  return $self->send($opt);
}

sub has_error {
  my ($self) = @_;

  return @{$self->{errors}} >= 0;
}

1;

__END__

=head1 EXAMPLE REQUEST

 POST /api/v3/projects/1/notices?key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx HTTP/1.1
 Host: errbit.suse.de
 User-Agent: BSAirBrake/0.01
 Content-Type: application/json
 Content-Length: 303

 {
 "params":{},
 "environment":{},
 "session":{},
 "context":{
  "environment":"development",
  "os":"linux",
  "language":""
 },
 "errors":
   [
     {
      "backtrace":[],
      "message":"Hello World from BSAirBrake",
      "type":"error"
     }
   ],
 "notifier":{
   "version":"0.0.1",
   "name":"BSAirBrake",
   "url":"https://github.com/openSUSE/open-build-service.git"
  }
 }

=head1 EXAMPLE RESPONSE

 HTTP/1.1 201 Created
 Date: Tue, 08 Aug 2017 00:20:35 GMT
 Server: Apache
 X-Frame-Options: SAMEORIGIN
 X-XSS-Protection: 1; mode=block
 X-Content-Type-Options: nosniff
 Access-Control-Allow-Origin: *
 Access-Control-Allow-Headers: origin, content-type, accept
 Content-Type: application/json; charset=utf-8
 ETag: W/"23106332831c4fde6fad737971350f58"
 Cache-Control: max-age=0, private, must-revalidate
 X-Request-Id: 7ba3fde3-488c-4d1c-8e27-15c05fd67081
 X-Runtime: 0.043996
 Vary: Accept-Encoding
 Transfer-Encoding: chunked

 80
 {"id":"598903d32bfc426f742eb8f2","url":"https://errbit.suse.de/apps/5978af4c2bfc426f742ea70e/problems/598903d32bfc426f742eb8f0"}
 0

=cut
