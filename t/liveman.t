use common::sense; use open qw/:std :utf8/; use Test::More 0.98; sub _mkpath_ { my ($p) = @_; length($`) && !-e $`? mkdir($`, 0755) || die "mkdir $`: $!": () while $p =~ m!/!g; $p } BEGIN { use Scalar::Util qw//; use Carp qw//; $SIG{__DIE__} = sub { my ($s) = @_; if(ref $s) { $s->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $s; die $s } else {die Carp::longmess defined($s)? $s: "undef" }}; my $t = `pwd`; chop $t; $t .= '/' . __FILE__; my $s = '/tmp/.liveman/perl-liveman!liveman/'; `rm -fr '$s'` if -e $s; chdir _mkpath_($s) or die "chdir $s: $!"; open my $__f__, "<:utf8", $t or die "Read $t: $!"; read $__f__, $s, -s $__f__; close $__f__; while($s =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { my ($file, $code) = ($1, $2); $code =~ s/^#>> //mg; open my $__f__, ">:utf8", _mkpath_($file) or die "Write $file: $!"; print $__f__ $code; close $__f__; } } # # NAME
# 
# Liveman - markdown compiller to test and pod.
# 
# # VERSION
# 
# 0.9.1
# 
# # SYNOPSIS
# 
# File lib/Example.md:
#@> lib/Example.md
#>> Twice two:
#>> ```perl
#>> 2*2  # -> 2+2
#>> ```
#@< EOF
# 
# Test:
subtest 'SYNOPSIS' => sub { 
use Liveman;

my $liveman = Liveman->new(prove => 1);

# compile lib/Example.md file to t/example.t and added pod to lib/Example.pm
$liveman->transform("lib/Example.md");

::is scalar do {$liveman->{count}}, "1", '$liveman->{count}   # => 1';
::is scalar do {-f "t/example.t"}, "1", '-f "t/example.t"    # => 1';
::is scalar do {-f "lib/Example.pm"}, "1", '-f "lib/Example.pm" # => 1';

# compile all lib/**.md files with a modification time longer than their corresponding test files (t/**.t)
$liveman->transforms;
::is scalar do {$liveman->{count}}, "0", '$liveman->{count}   # => 0';

# compile without check modification time
::is scalar do {Liveman->new(compile_force => 1)->transforms->{count}}, "1", 'Liveman->new(compile_force => 1)->transforms->{count} # => 1';

# start tests with yath
my $yath_return_code = $liveman->tests->{exit_code};

::is scalar do {$yath_return_code}, "0", '$yath_return_code           # => 0';
::is scalar do {-f "cover_db/coverage.html"}, "1", '-f "cover_db/coverage.html" # => 1';

# limit liveman to these files for operations transforms and tests (without cover)
my $liveman2 = Liveman->new(files => [], force_compile => 1);

# 
# # DESCRIPION
# 
# The problem with modern projects is that the documentation is disconnected from testing.
# This means that the examples in the documentation may not work, and the documentation itself may lag behind the code.
# 
# Liveman compile `lib/**`.md files to `t/**.t` files
# and it added pod-documentation to section `__END__` to `lib/**.pm` files.
# 
# Use `liveman` command for compile the documentation to the tests in catalog of your project and starts the tests:
# 
#     liveman
# 
# Run it with coverage.
# 
# Option `-o` open coverage in browser (coverage file: `cover_db/coverage.html`).
# 
# Liveman replace `our $VERSION = "...";` in `lib/**.pm` from `lib/**.md` if it exists in pm and in md.
# 
# If exists file **minil.toml**, then Liveman read `name` from it, and copy file with this name and extension `.md` to README.md.
# 
# ## TYPES OF TESTS
# 
# Section codes `noname` or `perl` writes as code to `t/**.t`-file. And comment with arrow translates on test from module `Test::More`.
# 
# The test name set as the code-line.
# 
# ### `is`
# 
# Compare two expressions for equivalence:
# 
done_testing; }; subtest '`is`' => sub { 
::is scalar do {"hi!"}, scalar do{"hi" . "!"}, '"hi!" # -> "hi" . "!"';
::is scalar do {"hi!"}, scalar do{"hi" . "!"}, '"hi!" # → "hi" . "!"';

# 
# ### `is_deeply`
# 
# Compare two expressions for structures:
# 
done_testing; }; subtest '`is_deeply`' => sub { 
::is_deeply scalar do {"hi!"}, scalar do {"hi" . "!"}, '"hi!" # --> "hi" . "!"';
::is_deeply scalar do {"hi!"}, scalar do {"hi" . "!"}, '"hi!" # ⟶ "hi" . "!"';

# 
# ### `is` with extrapolate-string
# 
# Compare expression with extrapolate-string:
# 
done_testing; }; subtest '`is` with extrapolate-string' => sub { 
my $exclamation = "!";
::is scalar do {"hi!2"}, "hi${exclamation}2", '"hi!2" # => hi${exclamation}2';
::is scalar do {"hi!2"}, "hi${exclamation}2", '"hi!2" # ⇒ hi${exclamation}2';

# 
# ### `is` with nonextrapolate-string
# 
# Compare expression with nonextrapolate-string:
# 
done_testing; }; subtest '`is` with nonextrapolate-string' => sub { 
::is scalar do {'hi${exclamation}3'}, 'hi${exclamation}3', '\'hi${exclamation}3\' # \> hi${exclamation}3';
::is scalar do {'hi${exclamation}3'}, 'hi${exclamation}3', '\'hi${exclamation}3\' # ↦ hi${exclamation}3';

# 
# ### `like`
# 
# It check a regular expression included in the expression:
# 
done_testing; }; subtest '`like`' => sub { 
::like scalar do {'abbc'}, qr!b+!, '\'abbc\' # ~> b+';
::like scalar do {'abc'}, qr!b+!, '\'abc\'  # ↬ b+';

# 
# ### `unlike`
# 
# It check a regular expression excluded in the expression:
# 
done_testing; }; subtest '`unlike`' => sub { 
::unlike scalar do {'ac'}, qr!b+!, '\'ac\' # <~ b+';
::unlike scalar do {'ac'}, qr!b+!, '\'ac\' # ↫ b+';

# 
# ## EMBEDDING FILES
# 
# Each test is executed in a temporary directory, which is erased and created when the test is run.
# 
# This directory format is /tmp/.liveman/*project*/*path-to-test*/.
# 
# Code section in md-file prefixed line **File `path`:** write to file in rintime testing.
# 
# Code section in md-file prefixed line **File `path` is:** will be compared with the file by the method `Test::More::is`.
# 
# File experiment/test.txt:
#@> experiment/test.txt
#>> hi!
#@< EOF
# 
# File experiment/test.txt is:

{ my $s = 'experiment/test.txt'; open my $__f__, '<:utf8', $s or die "Read $s: $!"; my $n = join '', <$__f__>; close $__f__; ::is $n, 'hi!
', "File $s"; }
# 
# **Attention!** An empty string between the prefix and the code is not allowed!
# 
# Prefixes maybe on russan: `Файл path:` and `Файл path является:`.
# 
# # METHODS
# 
# ## new (%param)
# 
# Constructor. Has arguments:
# 
# 1. `files` (array_ref) — list of md-files for methods `transforms` and `tests`.
# 1. `open` (boolean) — open coverage in browser. If is **opera** browser — open in it. Else — open via `xdg-open`.
# 1. `force_compile` (boolean) — do not check the md-files modification time.
# 1. `options` — add options in command line to yath or prove.
# 1. `prove` — use prove, but use'nt yath.
# 
# ## test_path ($md_path)
# 
# Get the path to the `t/**.t`-file from the path to the `lib/**.md`-file:
# 
done_testing; }; subtest 'test_path ($md_path)' => sub { 
::is scalar do {Liveman->new->test_path("lib/PathFix/RestFix.md")}, "t/path-fix/rest-fix.t", 'Liveman->new->test_path("lib/PathFix/RestFix.md") # => t/path-fix/rest-fix.t';

# 
# ## transform ($md_path, [$test_path])
# 
# Compile `lib/**.md`-file to `t/**.t`-file.
# 
# And method `transform` replace the **pod**-documentation in section `__END__` in `lib/**.pm`-file. And create `lib/**.pm`-file if it not exists.
# 
# File lib/Example.pm is:

{ my $s = 'lib/Example.pm'; open my $__f__, '<:utf8', $s or die "Read $s: $!"; my $n = join '', <$__f__>; close $__f__; ::is $n, 'package Example;

1;

__END__

=encoding utf-8

Twice two:

	2*2  # -> 2+2

', "File $s"; }
# 
# File `lib/Example.pm` was created from file `lib/Example.md` described in section `SINOPSIS` in this document.
# 
# ## transforms ()
# 
# Compile `lib/**.md`-files to `t/**.t`-files.
# 
# All if `$self->{files}` is empty, or `$self->{files}`.
# 
# ## tests ()
# 
# Tests `t/**.t`-files.
# 
# All if `$self->{files}` is empty, or `$self->{files}` only.
# 
# ## mkmd ($md)
# 
# It make md-file.
# 
# ## appends ()
# 
# Append to `lib/**.md` from `lib/**.pm` subroutines and features.
# 
# ## append ($path)
# 
# Append subroutines and features from the module with `$path` into its documentation in the its sections.
# 
# File lib/Alt/The/Plan.pm:
#@> lib/Alt/The/Plan.pm
#>> package Alt::The::Plan;
#>> 
#>> sub planner {
#>> 	my ($self) = @_;
#>> }
#>> 
#>> # This is first!
#>> sub miting {
#>> 	my ($self, $meet, $man, $woman) = @_;
#>> }
#>> 
#>> sub _exquise_me {
#>> 	my ($self, $meet, $man, $woman) = @_;
#>> }
#>> 
#>> 1;
#@< EOF
# 
done_testing; }; subtest 'append ($path)' => sub { 
::is scalar do {-e "lib/Alt/The/Plan.md"}, scalar do{undef}, '-e "lib/Alt/The/Plan.md" # -> undef';

# Set the mocks:
*Liveman::_git_user_name = sub {'Yaroslav O. Kosmina'};
*Liveman::_git_user_email = sub {'dart@cpan.org'};
*Liveman::_year = sub {2023};
*Liveman::_license = sub {"Perl5"};
*Liveman::_land = sub {"Rusland"};

my $liveman = Liveman->new->append("lib/Alt/The/Plan.pm");
::is scalar do {$liveman->{count}}, scalar do{1}, '$liveman->{count}	# -> 1';
::is scalar do {$liveman->{added}}, scalar do{2}, '$liveman->{added}	# -> 2';

::is scalar do {-e "lib/Alt/The/Plan.md"}, scalar do{1}, '-e "lib/Alt/The/Plan.md" # -> 1';

# And again:
$liveman = Liveman->new->append("lib/Alt/The/Plan.pm");
::is scalar do {$liveman->{count}}, scalar do{1}, '$liveman->{count}	# -> 1';
::is scalar do {$liveman->{added}}, scalar do{0}, '$liveman->{added}	# -> 0';

# 
# File lib/Alt/The/Plan.md is:

{ my $s = 'lib/Alt/The/Plan.md'; open my $__f__, '<:utf8', $s or die "Read $s: $!"; my $n = join '', <$__f__>; close $__f__; ::is $n, '# NAME

Alt::The::Plan - 

# SYNOPSIS

```perl
use Alt::The::Plan;

my $alt_the_plan = Alt::The::Plan->new;
```

# DESCRIPION

.

# SUBROUTINES

## miting ($meet, $man, $woman)

This is first!

```perl
my $alt_the_plan = Alt::The::Plan->new;
$alt_the_plan->miting($meet, $man, $woman)  # -> .3
```

## planner ()

.

```perl
my $alt_the_plan = Alt::The::Plan->new;
$alt_the_plan->planner  # -> .3
```

# INSTALL

For install this module in your system run next [command](https://metacpan.org/pod/App::cpm):

```sh
sudo cpm install -gvv Alt::The::Plan
```

# AUTHOR

Yaroslav O. Kosmina [dart@cpan.org](mailto:dart@cpan.org)

# LICENSE

⚖ **Perl5**

# COPYRIGHT

The Alt::The::Plan module is copyright © 2023 Yaroslav O. Kosmina. Rusland. All rights reserved.
', "File $s"; }
# 
# # INSTALL
# 
# Add to **cpanfile** in your project:
# 

# on 'test' => sub {
# 	requires 'Liveman', 
# 		git => 'https://github.com/darviarush/perl-liveman.git',
# 		ref => 'master',
# 	;
# };

# 
# And run command:
# 

# $ sudo cpm install -gvv

# 
# # AUTHOR
# 
# Yaroslav O. Kosmina [dart@cpan.org](mailto:dart@cpan.org)
# 
# # LICENSE
# 
# ⚖ **GPLv3**
# 
# # COPYRIGHT
# 
# The Alt::The::Plan module is copyright © 2023 Yaroslav O. Kosmina. Rusland. All rights reserved.

	done_testing;
};

done_testing;
