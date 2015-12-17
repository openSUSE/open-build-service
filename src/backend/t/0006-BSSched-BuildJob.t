use strict;
use warnings;

use Test::More tests => 6;
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

exit 0;
sub get_file_content {
  my ($file) = @_;
  open(FH,"< $file") or die $!;
  my @content = <FH>;
  close(FH);
  return \@content
}

