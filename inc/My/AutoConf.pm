package My::AutoConf;

use strict;
use warnings;
use Config::AutoConf;
use Config;
use File::Spec;
use FindBin;
use My::ShareConfig;
use lib 'lib';
use FFI::Probe;
use FFI::Probe::Runner;

my $root = $FindBin::Bin;

my $prologue = <<EOF;
#ifdef HAVE_DLFCN_H
#include <dlfcn.h>
#endif
#ifdef HAVE_ALLOCA_H
#include <alloca.h>
#endif
#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif
#ifdef HAVE_COMPLEX_H
#include <complex.h>
#endif
#define signed(type)  (((type)-1) < 0) ? 1 : 0
EOF

my @probe_types = split /\n/, <<EOF;
char
signed char
unsigned char
short
signed short
unsigned short
int
signed int
unsigned int
long
signed long
unsigned long
uint8_t
int8_t
uint16_t
int16_t
uint32_t
int32_t
uint64_t
int64_t
size_t
ssize_t
float
double
long double
float complex
double complex
long double complex
bool
_Bool
pointer
EOF

my @extra_probe_types = split /\n/, <<EOF;
long long
signed long long
unsigned long long
dev_t
ino_t
mode_t
nlink_t
uid_t
gid_t
off_t
blksize_t
blkcnt_t
time_t
int_least8_t
int_least16_t
int_least32_t
int_least64_t
uint_least8_t
uint_least16_t
uint_least32_t
uint_least64_t
ptrdiff_t
wchar_t
wint_t
EOF

push @probe_types, @extra_probe_types unless $ENV{FFI_PLATYPUS_NO_EXTRA_TYPES};

my $config_h = File::Spec->rel2abs( File::Spec->catfile( 'include', 'ffi_platypus_config.h' ) );

sub configure
{
  my($self) = @_;

  my $share_config = My::ShareConfig->new;
  my $probe = FFI::Probe->new(
    runner => FFI::Probe::Runner->new(
      exe => "blib/lib/auto/share/dist/FFI-Platypus/probe/bin/dlrun$Config{exe_ext}",
    ),
    log => "blib/lib/auto/share/dist/FFI-Platypus/probe/probe.log",
    data_filename => "blib/lib/auto/share/dist/FFI-Platypus/probe/probe.pl",
  );

  return if -r $config_h && ref($share_config->get( 'type_map' )) eq 'HASH';

  my $ac = Config::AutoConf->new;

  $ac->check_prog_cc;

  $ac->define_var( do {
    my $os = uc $^O;
    $os =~ s/-/_/;
    $os =~ s/[^A-Z0-9_]//g;
    "PERL_OS_$os";
  } => 1 );

  $ac->define_var( PERL_OS_WINDOWS => 1 ) if $^O =~ /^(MSWin32|cygwin|msys)$/;

  foreach my $header (qw( stdlib stdint sys/types sys/stat unistd alloca dlfcn limits stddef wchar signal inttypes windows sys/cygwin string psapi stdio stdbool complex ))
  {
    $ac->check_header("$header.h");
    $probe->check_header("$header.h");
  }

  $ac->check_stdc_headers;

  unless($share_config->get('config_no_alloca'))
  {
    if($ac->check_decl('alloca', { prologue => $prologue }))
    {
      $ac->define_var( HAVE_ALLOCA => 1 );
    }
  }

  if(!$share_config->get('config_debug_fake32') && $Config{ivsize} >= 8)
  {
    $ac->define_var( HAVE_IV_IS_64 => 1 );
  }
  else
  {
    $ac->define_var( HAVE_IV_IS_64 => 0 );
  }

  my %type_map;
  my %align;

  foreach my $type (@probe_types)
  {
    my $ok;

    if($type =~ /^(float|double|long double)/)
    {
      if(my $basic = $probe->check_type_float($type))
      {
        $type_map{$type} = $basic;
        $align{$type} = $probe->data->{type}->{$type}->{align};
      }
    }
    elsif($type eq 'pointer')
    {
      $probe->check_type_pointer;
      $align{pointer} = $probe->data->{type}->{pointer}->{align};
    }
    else
    {
      if(my $basic = $probe->check_type_int($type))
      {
        $type_map{$type} = $basic;
        $align{$basic} ||= $probe->data->{type}->{$type}->{align};
      }
    }
  }

  $ac->define_var( SIZEOF_VOIDP => $probe->data->{type}->{pointer}->{size} );
  if(my $size = $probe->data->{type}->{'float complex'}->{size})
  { $ac->define_var( SIZEOF_FLOAT_COMPLEX => $size ) }
  if(my $size = $probe->data->{type}->{'double complex'}->{size})
  { $ac->define_var( SIZEOF_DOUBLE_COMPLEX => $size ) }
  if(my $size = $probe->data->{type}->{'long double complex'}->{size})
  { $ac->define_var( SIZEOF_LONG_DOUBLE_COMPLEX => $size ) }

  # short aliases
  $type_map{uchar}  = $type_map{'unsigned char'};
  $type_map{ushort} = $type_map{'unsigned short'};
  $type_map{uint}   = $type_map{'unsigned int'};
  $type_map{ulong}  = $type_map{'unsigned long'};

  # on Linux and OS X at least the test for bool fails
  # but _Bool works (even though code using bool seems
  # to work for both).  May be because bool is a macro
  # for _Bool or something.
  $type_map{bool} ||= delete $type_map{_Bool};
  delete $type_map{_Bool};

  $ac->write_config_h( $config_h );
  $share_config->set( type_map => \%type_map );
  $share_config->set( align    => \%align    );
}

sub _alignment
{
  my($ac, $type) = @_;
  my $align = $ac->check_alignof_type($type);
  return $align if $align;

  # This no longer seems necessary now that we do a
  # check_default_headers above.  See:
  # # https://github.com/ambs/Config-AutoConf/issues/7
  my $btype = $type eq 'void*' ? 'vpointer' : "b$type";
  $btype =~ s/\s+/_/g;
  my $prologue2 = $prologue . <<EOF;
#ifdef HAVE_COMPLEX_H
#include <complex.h>
#endif
struct align {
  char a;
    $type $btype;
  };
EOF
  return $ac->compute_int("__builtin_offsetof(struct align, $btype)", { prologue => $prologue2 });
}

sub clean
{
  unlink $config_h;
}

1;
