use common::sense; use open qw/:std :utf8/;  use Carp qw//; use Cwd qw//; use File::Basename qw//; use File::Find qw//; use File::Slurper qw//; use File::Spec qw//; use File::Path qw//; use Scalar::Util qw//;  use Test::More 0.98;  use String::Diff qw//; use Data::Dumper qw//; use Term::ANSIColor qw//;  BEGIN { 	$SIG{__DIE__} = sub { 		my ($msg) = @_; 		if(ref $msg) { 			$msg->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $msg; 			die $msg; 		} else { 			die Carp::longmess defined($msg)? $msg: "undef" 		} 	}; 	 	my $t = File::Slurper::read_text(__FILE__); 	 	my @dirs = File::Spec->splitdir(File::Basename::dirname(Cwd::abs_path(__FILE__))); 	my $project_dir = File::Spec->catfile(@dirs[0..$#dirs-2]); 	my $project_name = $dirs[$#dirs-2]; 	my @test_dirs = @dirs[$#dirs-2+2 .. $#dirs];  	$ENV{TMPDIR} = $ENV{LIVEMAN_TMPDIR} if exists $ENV{LIVEMAN_TMPDIR};  	my $dir_for_tests = File::Spec->catfile(File::Spec->tmpdir, ".liveman", $project_name, join("!", @test_dirs, File::Basename::basename(__FILE__))); 	 	File::Find::find(sub { chmod 0700, $_ if !/^\.{1,2}\z/ }, $dir_for_tests), File::Path::rmtree($dir_for_tests) if -e $dir_for_tests; 	File::Path::mkpath($dir_for_tests); 	 	chdir $dir_for_tests or die "chdir $dir_for_tests: $!"; 	 	push @INC, "$project_dir/lib", "lib"; 	 	$ENV{PROJECT_DIR} = $project_dir; 	$ENV{DIR_FOR_TESTS} = $dir_for_tests; 	 	while($t =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { 		my ($file, $code) = ($1, $2); 		$code =~ s/^#>> //mg; 		File::Path::mkpath(File::Basename::dirname($file)); 		File::Slurper::write_text($file, $code); 	} }  my $white = Term::ANSIColor::color('BRIGHT_WHITE'); my $red = Term::ANSIColor::color('BRIGHT_RED'); my $green = Term::ANSIColor::color('BRIGHT_GREEN'); my $reset = Term::ANSIColor::color('RESET'); my @diff = ( 	remove_open => "$white\[$red", 	remove_close => "$white]$reset", 	append_open => "$white\{$green", 	append_close => "$white}$reset", );  sub _string_diff { 	my ($got, $expected, $chunk) = @_; 	$got = substr($got, 0, length $expected) if $chunk == 1; 	$got = substr($got, -length $expected) if $chunk == -1; 	String::Diff::diff_merge($got, $expected, @diff) }  sub _struct_diff { 	my ($got, $expected) = @_; 	String::Diff::diff_merge( 		Data::Dumper->new([$got], ['diff'])->Indent(0)->Useqq(1)->Dump, 		Data::Dumper->new([$expected], ['diff'])->Indent(0)->Useqq(1)->Dump, 		@diff 	) }  # 
# # NAME
# 
# Liveman::Cpanfile - анализатор зависимостей Perl проекта
# 
# # SYNOPSIS
# 
subtest 'SYNOPSIS' => sub { 
use Liveman::Cpanfile;

my $result = << 'END';
requires 'perl', '5.22.0';

on 'develop' => sub {
	requires 'App::cpm';
	requires 'CPAN::Uploader';
	requires 'Data::Printer', '1.000004';
	requires 'Minilla', 'v3.1.19';
	requires 'Liveman', '1.0';
	requires 'Software::License::GPL_3';
	requires 'V';
	requires 'Version::Next';
};

on 'test' => sub {
	requires 'Car::Auto';
	requires 'Carp';
	requires 'Cwd';
	requires 'Data::Dumper';
	requires 'File::Basename';
	requires 'File::Find';
	requires 'File::Path';
	requires 'File::Slurper';
	requires 'File::Spec';
	requires 'Scalar::Util';
	requires 'String::Diff';
	requires 'Term::ANSIColor';
	requires 'Test::More';
	requires 'Turbin';
	requires 'open';
};

requires 'Data::Printer';
requires 'List::Util';
requires 'common::sense';
requires 'strict';
requires 'warnings';
END

chmod 0755, $_ for qw!script/test_script bin/tool!;

$::cpanfile = Liveman::Cpanfile->new;
{ my $got = do {$::cpanfile->cpanfile}; my $ex = do {$result}; ::ok defined($got) == defined($ex) && ref $got eq ref $ex && $got eq $ex, '$::cpanfile->cpanfile # -> $result' or ::diag ::_struct_diff($got, $ex) }
# 
# # DESCRIPTION
# 
# `Liveman::Cpanfile` анализирует структуру Perl проекта и извлекает информацию о зависимостях из исходного кода, тестов и документации. Модуль автоматически определяет используемые модули и помогает поддерживать актуальный `cpanfile`.
# 
# # SUBROUTINES
# 
# ## new ()
# 
# Конструктор.
# 
# ## pkg_from_path ()
# 
# Преобразует путь к файлу в имя пакета Perl.
# 
::done_testing; }; subtest 'pkg_from_path ()' => sub { 
{ my $got = do {Liveman::Cpanfile::pkg_from_path('lib/My/Module.pm')}; my $ex = "My::Module"; ::ok $got eq $ex, 'Liveman::Cpanfile::pkg_from_path(\'lib/My/Module.pm\') # => My::Module' or ::diag ::_string_diff($got, $ex) }
{ my $got = do {Liveman::Cpanfile::pkg_from_path('lib/My/App.pm')}; my $ex = "My::App"; ::ok $got eq $ex, 'Liveman::Cpanfile::pkg_from_path(\'lib/My/App.pm\')    # => My::App' or ::diag ::_string_diff($got, $ex) }

# 
# ## sc ()
# 
# Возвращает список исполняемых скриптов в директориях `script/` и `bin/`.
# 
# Файл script/test_script:
#@> script/test_script
#>> #!/usr/bin/env perl
#>> require Data::Printer;
#@< EOF
# 
# Файл bin/tool:
#@> bin/tool
#>> #!/usr/bin/env perl
#>> use List::Util;
#@< EOF
# 
::done_testing; }; subtest 'sc ()' => sub { 
{ my $got = do {[$::cpanfile->sc]}; my $ex = do {[qw!bin/tool script/test_script!]}; ::is_deeply $got, $ex, '[$::cpanfile->sc] # --> [qw!bin/tool script/test_script!]' or ::diag ::_struct_diff($got, $ex) }

# 
# ## pm ()
# 
# Возвращает список Perl модулей в директории `lib/`.
# 
# Файл lib/My/Module.pm:
#@> lib/My/Module.pm
#>> package My::Module;
#>> use strict;
#>> use warnings;
#>> 1;
#@< EOF
# 
# Файл lib/My/Other.pm:
#@> lib/My/Other.pm
#>> package My::Other;
#>> use common::sense;
#>> 1;
#@< EOF
# 
::done_testing; }; subtest 'pm ()' => sub { 
{ my $got = do {[$::cpanfile->pm]}; my $ex = do {[qw!lib/My/Module.pm lib/My/Other.pm!]}; ::is_deeply $got, $ex, '[$::cpanfile->pm]  # --> [qw!lib/My/Module.pm lib/My/Other.pm!]' or ::diag ::_struct_diff($got, $ex) }

# 
# ## mod ()
# 
# Возвращает список имен пакетов проекта соответствующих модулям в директории `lib/`.
# 
::done_testing; }; subtest 'mod ()' => sub { 
{ my $got = do {[$::cpanfile->mod]}; my $ex = do {[qw/My::Module My::Other/]}; ::is_deeply $got, $ex, '[$::cpanfile->mod]  # --> [qw/My::Module My::Other/]' or ::diag ::_struct_diff($got, $ex) }

# 
# ## md ()
# 
# Возвращает список Markdown файлов документации (`*.md`) в `lib/`.
# 
# Файл lib/My/Module.md:
#@> lib/My/Module.md
#>> # My::Module
#>> 
#>> This is a module for experiment with package My::Module.
#>> ```perl
#>> package My {}
#>> package My::Third {}
#>> use My::Other;
#>> use My;
#>> use Turbin;
#>> use Car::Auto;
#>> ```
#@< EOF
# 
::done_testing; }; subtest 'md ()' => sub { 
{ my $got = do {[$::cpanfile->md]}; my $ex = do {[qw!lib/My/Module.md!]}; ::is_deeply $got, $ex, '[$::cpanfile->md]  # --> [qw!lib/My/Module.md!]' or ::diag ::_struct_diff($got, $ex) }

# 
# ## md_mod ()
# 
# Список внедрённых в `*.md` пакетов.
# 
::done_testing; }; subtest 'md_mod ()' => sub { 
{ my $got = do {[$::cpanfile->md_mod]}; my $ex = do {[qw!My My::Third!]}; ::is_deeply $got, $ex, '[$::cpanfile->md_mod]  # --> [qw!My My::Third!]' or ::diag ::_struct_diff($got, $ex) }

# 
# ## deps ()
# 
# Список зависимостей явно указанных в скриптах и модулях без пакетов проекта.
# 
::done_testing; }; subtest 'deps ()' => sub { 
{ my $got = do {[$::cpanfile->deps]}; my $ex = do {[qw!Data::Printer List::Util common::sense strict warnings!]}; ::is_deeply $got, $ex, '[$::cpanfile->deps]  # --> [qw!Data::Printer List::Util common::sense strict warnings!]' or ::diag ::_struct_diff($got, $ex) }

# 
# ## t_deps ()
# 
# Список зависимостей из тестов за исключением:
# 
# 1. Зависмостей скриптов и модулей.
# 2. Пакетов проекта.
# 3. Внедрённых в `*.md` пакетов.
# 
::done_testing; }; subtest 't_deps ()' => sub { 
{ my $got = do {[$::cpanfile->t_deps]}; my $ex = do {[qw!Car::Auto Carp Cwd Data::Dumper File::Basename File::Find File::Path File::Slurper File::Spec Scalar::Util String::Diff Term::ANSIColor Test::More Turbin open!]}; ::is_deeply $got, $ex, '[$::cpanfile->t_deps]  # --> [qw!Car::Auto Carp Cwd Data::Dumper File::Basename File::Find File::Path File::Slurper File::Spec Scalar::Util String::Diff Term::ANSIColor Test::More Turbin open!]' or ::diag ::_struct_diff($got, $ex) }

# 
# ## cpanfile ()
# 
# Возвращает текст cpanfile c зависимостями для проекта.
# 
# # AUTHOR
# 
# Yaroslav O. Kosmina <dart@cpan.org>
# 
# # LICENSE
# 
# ⚖ **GPLv3**
# 
# # COPYRIGHT
# 
# The Liveman::Cpanfile module is copyright © 2025 Yaroslav O. Kosmina. Rusland. All rights reserved.

	::done_testing;
};

::done_testing;
