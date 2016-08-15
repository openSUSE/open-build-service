use strict;
use warnings;

use Test::More tests => 23; 

require_ok('BSFileDB');

# start data definition and set some global vars
my $fn = '/tmp/test_file_db';
my $s_layout = [ qw { name surname gender ident } ];
my $data = {
  name => 'john', 
  surname => 'doe',
  gender => 'm', 
  ident => 'ms',
};
my $data_m1 = {
  name => 'julia', 
  surname => 'doe',
  gender => 'w', 
  ident => 'mt',
};
my $data_m2 = {
  name => 'juan', 
  surname => 'doe',
  gender => 'm', 
  ident => 'mr',
};
my @mult_arr;
push @mult_arr, $data_m1;
push @mult_arr, $data_m2;

my $i_layout = [ qw { rev version pkg comment } ]; #layout for incremental test
my $i2_layout = [ qw { rev vrev version pkg comment } ]; #layout for i2 tests
my @c_data = (  
   { 'version'=>'1.0.0', 'pkg'=>'test', 'comment'=>'first entry of version 1' },
   { 'version'=>'1.0.0', 'pkg'=>'test', 'comment'=>'second entry of version 1' },
   { 'version'=>'1.0.1', 'pkg'=>'test', 'comment'=>'first entry of version 2' },
);
# end data definition

unlink($fn) if -e $fn; #unlink if exists (broken test before)

# test add functions
my $file_is = ok ( eval { BSFileDB::fdb_add($fn,$s_layout,$data) }, "BSFileDB creating test file $fn and adding data");
is_deeply(BSFileDB::fdb_getlast($fn,$s_layout), $data, "BSFileDB inspecting data in $fn");
ok(eval{ BSFileDB::fdb_add_multiple($fn,$s_layout,@mult_arr) }, "BSFileDB adding multiple data structs");

# test match functions
my $get_str = BSFileDB::fdb_getmatch($fn,$s_layout,'name','john');
is($get_str->{'ident'}, $data->{'ident'}, "BSFileDB testing search in $fn");
$get_str = BSFileDB::fdb_getmatch($fn,$s_layout,'surname','doe');
is($get_str->{'ident'}, $data->{'ident'}, "BSFileDB testing ambiguous search for first matching entry in $fn");
$get_str = BSFileDB::fdb_getmatch($fn,$s_layout,'surname','doe', 1);
is($get_str->{'ident'}, $data_m2->{'ident'}, "BSFileDB testing ambiguous search for last matching entry in $fn");

# test get functions
$get_str = BSFileDB::fdb_getlast($fn,$s_layout);
is($get_str->{'ident'}, $data_m2->{'ident'}, "BSFileDB getting last entry");
my @get_arr = BSFileDB::fdb_getall($fn,$s_layout,undef);
is(scalar(@get_arr),3,"Getting all entries from $fn");
is($get_arr[2]->{'ident'},'mr',"Checking order");

# test getall function with filter coderef
@get_arr = (); 
@get_arr = BSFileDB::fdb_getall($fn,$s_layout,undef,\&nomales);
is(scalar(@get_arr),1,"Getting just some entries from $fn based on code ref");

@get_arr = BSFileDB::fdb_getall_reverse($fn,$s_layout,undef);
is($get_arr[2]->{'ident'},'ms',"Checking reverse order");

# clean our file
unlink($fn);

# Fill filedb with autoincrement
ok ( eval { BSFileDB::fdb_add_i($fn,$i_layout,$c_data[0]) }, "BSFileDB adding first incremental entry (function fdb_add_i)");
ok ( eval { BSFileDB::fdb_add_i($fn,$i_layout,$c_data[1]) }, "BSFileDB adding second incremental entry (function fdb_add_i)");
ok ( eval { BSFileDB::fdb_add_i($fn,$i_layout,$c_data[2]) }, "BSFileDB adding third incremental entry (function fdb_add_i)");

# check if autoincrement worked
my $ret_st = BSFileDB::fdb_getlast($fn,$i_layout);
is($ret_st->{'rev'},3,"BSFileDB checking last incremented value");

# clean our file again
unlink($fn); 
 
# fill filedb with i2 (dependent autoincrement) data
ok ( eval { BSFileDB::fdb_add_i2($fn,$i2_layout,$c_data[0],'vrev','version',$c_data[0]->{'version'}) }, "BSFileDB adding first incremental entry (function fdb_add_i2)");
ok ( eval { BSFileDB::fdb_add_i2($fn,$i2_layout,$c_data[1],'vrev','version',$c_data[1]->{'version'}) }, "BSFileDB adding second incremental entry (function fdb_add_i2)");

# check if everything is ok until now. 
$ret_st = BSFileDB::fdb_getlast($fn,$i2_layout);
is($ret_st->{'rev'},2,"BSFileDB checking rev of second entry");
is($ret_st->{'vrev'},2,"BSFileDB checking rev of second entry");

# reset dependent key with new version value
ok ( eval { BSFileDB::fdb_add_i2($fn,$i2_layout,$c_data[2],'vrev','version',$c_data[2]->{'version'}) }, "BSFileDB adding third incremental entry (function fdb_add_i2)");

# check if reset worked. vrev must be 1 again. 
$ret_st = BSFileDB::fdb_getlast($fn,$i2_layout);
is($ret_st->{'rev'},3,"BSFileDB checking rev of second entry");
is($ret_st->{'vrev'},1,"BSFileDB checking rev of second entry");

# and finally kill the file
unlink($fn);

# filter function to test filter coderef
sub nomales {
  return 0 if $_[0]->{'gender'} eq 'm';
  return 1;
}

exit 0;
