#
# DO NOT MODIFY THIS FILE.
# Thisfile generated from similar file t/type_uint8.t
# all instances of "int8" have been changed to "int64"
#
use strict;
use warnings;
use Test::More tests => 14;
use FFI::CheckLib;
use FFI::Platypus::Declare
  'uint64', 'void', 'int',
  ['uint64 *' => 'uint64_p'],
  ['uint64 [10]' => 'uint64_a'],
  ['(uint64)->uint64' => 'uint64_c'];

lib find_lib lib => 'test', symbol => 'f0', libpath => 'libtest';

function [uint64_add => 'add'] => [uint64, uint64] => uint64;
function [uint64_inc => 'inc'] => [uint64_p, uint64] => uint64_p;
function [uint64_sum => 'sum'] => [uint64_a] => uint64;
function [uint64_array_inc => 'array_inc'] => [uint64_a] => void;
function [pointer_null => 'null'] => [] => uint64_p;
function [pointer_is_null => 'is_null'] => [uint64_p] => int;
function [uint64_static_array => 'static_array'] => [] => uint64_a;
function [pointer_null => 'null2'] => [] => uint64_a;

is add(1,2), 3, 'add(1,2) = 3';

my $i = 3;
is ${inc(\$i, 4)}, 7, 'inc(\$i,4) = \7';

is $i, 3+4, "i=3+4";

is ${inc(\3,4)}, 7, 'inc(\3,4) = \7';

my @list = (1,2,3,4,5,6,7,8,9,10);

is sum(\@list), 55, 'sum([1..10]) = 55';

array_inc(\@list);

is_deeply \@list, [2,3,4,5,6,7,8,9,10,11], 'array increment';

is null(), undef, 'null() == undef';
is is_null(undef), 1, 'is_null(undef) == 1';
is is_null(\22), 0, 'is_null(22) == 0';

is_deeply static_array(), [1,4,6,8,10,12,14,16,18,20], 'static_array = [1,4,6,8,10,12,14,16,18,20]';

is null2(), undef, 'null2() == undef';

my $closure = closure { $_[0]+2 };
function [uint64_set_closure => 'set_closure'] => [uint64_c] => void;
function [uint64_call_closure => 'call_closure'] => [uint64] => uint64;

set_closure($closure);
is call_closure(2), 4, 'call_closure(2) = 4';

$closure = closure { undef };
set_closure($closure);
is do { no warnings; call_closure(2) }, 0, 'call_closure(2) = 0';

subtest 'custom type input' => sub {
  my $save;
  custom_type uint64 => type1 => sub { $save = $_[1]; $_[0]*2 }, undef, [1,2,3];
  function [uint64_add => 'custom_add'] => ['type1',uint64] => uint64;
  is custom_add(2,1), 5, 'custom_add(2,1) = 5';
  is_deeply $save, [1,2,3], 'userdata = [1,2,3]';
};
