use strict;
use warnings;

use Test::More tests => 13;
use Data::Dumper;
use feature qw/say/;

require_ok('BSSched::BuildJob');


my ($got,$expected,$fixture);

################################################################################
my @basefile = split('/',__FILE__);
my $basename = pop(@basefile);
my $dirname  = join('/',@basefile);

$BSConfig::bsdir = $dirname . "/tmp/0006";
unlink($BSConfig::bsdir);
$BSSched::arch = 'x86_64';
$BSSched::reporoot = $dirname . "/tmp/0006/build";
my $prp           = 'openSUSE:Test/standard';
my $packid        = 'kernel';
my $fdir          = join('/',$BSSched::reporoot,$prp,$BSSched::arch);
my $pkg_finished  = join('/',$fdir,':packstatus.finished');
my $gctx	  = {
	reporoot => $dirname . "/tmp/0006/build",
	arch	 => 'x86_64' 
};

BSUtil::mkdir_p($fdir);
unlink $pkg_finished;
BSUtil::touch($pkg_finished);
# 
BSSched::BuildJob::patchpackstatus($gctx,'openSUSE:Test/standard','kernel','building');
my $content =  get_file_content($pkg_finished);
is_deeply($content,["building kernel\n"],'Checking content in packstatus.finished');
#
BSSched::BuildJob::patchpackstatus($gctx,'openSUSE:Test/standard','kernel');
$content =  get_file_content($pkg_finished);
is_deeply(
  $content,
  ["building kernel\n","unknown kernel\n"],
  'Checking content in packstatus.finished'
);

################################################################################

my $changes = BSSched::BuildJob::sortedmd5toreason('!a','+b','-c');
my @r = (
  {key=>'a',change=>'md5sum'},
  {key=>'b',change=>'added'},
  {key=>'c',change=>'removed'}
);
for my $got (@$changes) {
  my $expected = shift(@r);
  is_deeply($got,$expected,"Checking sortedmd5toreason" );
};

################################################################################
$fixture = {
  path => [
    { path => 'abc' , project => 'openSUSE:Factory' , repository => 'standard' },
  ],
};

@$got = BSSched::BuildJob::expandkiwipath($fixture);
$expected = [ 'openSUSE:Factory/standard' ];
is_deeply($got,$expected,'Checking testcase 1 TODO: better description');
################################################################################
$fixture = [
    {
      path => [
        { path => 'abc' , project => '_obsrepositories' },
      ],
    },
  ['prpsearchpath1','prpsearchpath2']
];
$expected = [ 'prpsearchpath1', 'prpsearchpath2' ];
@$got = BSSched::BuildJob::expandkiwipath(@$fixture);
is_deeply($got,$expected,'Checking with _obsrepositories and prpsearchpath');

################################################################################
$fixture = [
    {
      path => [
        { path => 'abc' , project => '_obsrepositories' },
      ],
    },
];
$expected = [ ];
@$got = BSSched::BuildJob::expandkiwipath(@$fixture);
is_deeply($got,$expected,'Checking with _obsrepositories w/o prpsearchpath');
################################################################################
@$got = BSSched::BuildJob::expandkiwipath();
$expected = [ 'openSUSE:Factory/standard' ];
is_deeply($got,[],'Checking empty $info->{path} element');

### Testing BSSched::BuildJob::jobname
$got= BSSched::BuildJob::jobname("openSUSE:Factory/standard","kernel");
is($got,'openSUSE:Factory::standard::kernel',"Checking jobname normal length");
################################################################################
$got= BSSched::BuildJob::jobname("openSUSE:Factory/standard","kernel". ( "x" x 200 ));
is($got,':cc9039e0510bfb4c513ff8c0f8360cab:::eb57b075a7e17391136eff38c63547e4',"Checking jobname oversized packid");
################################################################################
$got= BSSched::BuildJob::jobname("openSUSE:Factory/standard" . ( "x" x 200 ),"kernel");
is($got,':7f34cc064ad26bb6433937dee6e058b6::kernel',"Checking jobname oversized prp");
################################################################################

exit 0;
sub get_file_content {
  my ($file) = @_;
  open(FH,"< $file") or die $!;
  my @content = <FH>;
  close(FH);
  return \@content
}


