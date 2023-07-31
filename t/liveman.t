use strict; use warnings; use utf8; use open qw/:std :utf8/; use Test::More 0.98; sub _mkpath_ { my ($p) = @_; mkdir $`, 0755 while $p =~ m!/!g; $p } { my $s = '/tmp/.liveman/perl-liveman/liveman/'; `rm -fr $s` if -e $s; chdir _mkpath_($s) or die "chdir $s: $!" } # # NAME
# 
# Liveman - markdown compiller to test and pod.
# 
# # SYNOPSIS
# 
# File lib/Example.md:

{ my $s = main::_mkpath_('lib/Example.md'); open my $__f__, '>:utf8', $s or die "Read $s: $!"; print $__f__ 'Twice two:
```perl
2*2  # -> 2+2
```
'; close $__f__ }
# 
# Test:
subtest 'SYNOPSIS' => sub { 
use Liveman;

my $liveman = Liveman->new;

# compile lib/Example.md file to t/example.t and added pod to lib/Example.pm
$liveman->transform("lib/Example.md");

is scalar do {$liveman->{count}}, "1", '$liveman->{count}   # => 1';
is scalar do {-f "t/example.t"}, "1", '-f "t/example.t"    # => 1';
is scalar do {-f "lib/Example.pm"}, "1", '-f "lib/Example.pm" # => 1';

# compile all lib/**.md files with a modification time longer than their corresponding test files (t/**.t)
$liveman->transforms;
is scalar do {$liveman->{count}}, "0", '$liveman->{count}   # => 0';

# compile without check modification time
is scalar do {Liveman->new(compile_force => 1)->transforms->{count}}, "1", 'Liveman->new(compile_force => 1)->transforms->{count} # => 1';

# start tests with yath
my $yath_return_code = $liveman->tests->{exit_code};

is scalar do {$yath_return_code}, "0", '$yath_return_code           # => 0';
is scalar do {-f "cover_db/coverage.html"}, "1", '-f "cover_db/coverage.html" # => 1';

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
is scalar do {"hi!"}, scalar do{"hi" . "!"}, '"hi!" # -> "hi" . "!"';
is scalar do {"hi!"}, scalar do{"hi" . "!"}, '"hi!" # → "hi" . "!"';

# 
# ### `is_deeply`
# 
# Compare two expressions for structures:
# 
done_testing; }; subtest '`is_deeply`' => sub { 
is_deeply scalar do {"hi!"}, scalar do {"hi" . "!"}, '"hi!" # --> "hi" . "!"';
is_deeply scalar do {"hi!"}, scalar do {"hi" . "!"}, '"hi!" # ⟶ "hi" . "!"';

# 
# ### `is` with extrapolate-string
# 
# Compare expression with extrapolate-string:
# 
done_testing; }; subtest '`is` with extrapolate-string' => sub { 
my $exclamation = "!";
is scalar do {"hi!2"}, "hi${exclamation}2", '"hi!2" # => hi${exclamation}2';
is scalar do {"hi!2"}, "hi${exclamation}2", '"hi!2" # ⇒ hi${exclamation}2';

# 
# ### `is` with nonextrapolate-string
# 
# Compare expression with nonextrapolate-string:
# 
done_testing; }; subtest '`is` with nonextrapolate-string' => sub { 
is scalar do {'hi${exclamation}3'}, 'hi${exclamation}3', '\'hi${exclamation}3\' # \> hi${exclamation}3';
is scalar do {'hi${exclamation}3'}, 'hi${exclamation}3', '\'hi${exclamation}3\' # ↦ hi${exclamation}3';

# 
# ### `like`
# 
# It check a regular expression included in the expression:
# 
done_testing; }; subtest '`like`' => sub { 
like scalar do {'abbc'}, qr!b+!, '\'abbc\' # ~> b+';
like scalar do {'abc'}, qr!b+!, '\'abc\'  # ↬ b+';

# 
# ### `unlike`
# 
# It check a regular expression excluded in the expression:
# 
done_testing; }; subtest '`unlike`' => sub { 
unlike scalar do {'ac'}, qr!b+!, '\'ac\' # <~ b+';
unlike scalar do {'ac'}, qr!b+!, '\'ac\' # ↫ b+';

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

{ my $s = main::_mkpath_('experiment/test.txt'); open my $__f__, '>:utf8', $s or die "Read $s: $!"; print $__f__ 'hi!
'; close $__f__ }
# 
# File experiment/test.txt is:

{ my $s = main::_mkpath_('experiment/test.txt'); open my $__f__, '<:utf8', $s or die "Read $s: $!"; my $n = join '', <$__f__>; close $__f__; is $n, 'hi!
', "File $s"; }
# 
# **Attention!** An empty string between the prefix and the code is not allowed!
# 
# Prefixes maybe on russan: `Файл path:` and `Файл path является:`.
# 
# ## METHODS
# 
# ### new(files=>[...], open => 1, force_compile => 1)
# 
# Constructor. Has arguments:
# 
# 1. `files` (array_ref) — list of md-files for methods `transforms` and `tests`.
# 1. `open` (boolean) — open coverage in browser. If is **opera** browser — open in it. Else — open via `xdg-open`.
# 1. `force_compile` (boolean) — do not check the md-files modification time.
# 
# ### test_path($md_path)
# 
# Get the path to the `t/**.t`-file from the path to the `lib/**.md`-file:
# 
done_testing; }; subtest 'test_path($md_path)' => sub { 
is scalar do {Liveman->new->test_path("lib/PathFix/RestFix.md")}, "t/path-fix/rest-fix.t", 'Liveman->new->test_path("lib/PathFix/RestFix.md") # => t/path-fix/rest-fix.t';

# 
# ### transform($md_path, [$test_path])
# 
# Compile `lib/**.md`-file to `t/**.t`-file.
# 
# And method `transform` replace the **pod**-documentation in section `__END__` in `lib/**.pm`-file. And create `lib/**.pm`-file if it not exists.
# 
# File lib/Example.pm is:

{ my $s = main::_mkpath_('lib/Example.pm'); open my $__f__, '<:utf8', $s or die "Read $s: $!"; my $n = join '', <$__f__>; close $__f__; is $n, 'package Example;

1;

__END__

=encoding utf-8

Twice two:

	2*2  # -> 2+2

', "File $s"; }
# 
# ### transforms()
# 
# Compile `lib/**.md`-files to `t/**.t`-files.
# 
# All if `$self->{files}` is empty, or `$self->{files}`.
# 
# ### tests()
# 
# Tests `t/**.t`-files.
# 
# All if `$self->{files}` is empty, or `$self->{files}` only.
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
# # LICENSE
# 
# ⚖ **GPLv3**
# 
# # AUTHOR
# 
# Yaroslav O. Kosmina [dart@cpan.org](mailto:dart@cpan.org)
	done_testing;
};

done_testing;
