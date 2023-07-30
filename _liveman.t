use utf8;
use strict;
use open qw/:std :utf8/;

use Test::More 0.98;

use Cwd;
use File::Slurper qw/write_text read_text/;

use constant {
    DIR => "/tmp/ray-test",
    MD => "lib/ray_test_Mod.md",
    PM => "lib/ray_test_Mod.pm",
    TEST => "t/ray_test_-mod.t",

	MD2 => "lib/Mod2.md",
    PM2 => "lib/Mod2.pm",
    TEST2 => "t/mod2.t",
};

my $liveman = Cwd::abs_path("script/liveman");
my $lib = Cwd::abs_path("lib");

system "rm -fr ${\DIR}";

mkdir DIR, 0755 or die DIR . " mkdir: $!";
chdir DIR or die DIR . " chdir: $!";

# Должно быть 2 файла: lib/ray_test_Mod.md и lib/ray_test_Mod.pm

mkdir "lib", 0755;

write_text PM, << 'END';
package ray_test_Mod;

our $A = 10;
our $B = [1, 2, 3];
our $C = "\$hi";

1;
END

write_text MD, << 'END';
# NAME

ray_test_Mod — тестовый модуль

# SYNOPSIS

```perl
use ray_test_Mod;

$ray_test_Mod::A # -> 5+5
$ray_test_Mod::B # --> [1, 2, 3]

my $dollar = '$';
$ray_test_Mod::C # => ${dollar}hi

$ray_test_Mod::C # \> $hi


$ray_test_Mod::A # → 5+5
$ray_test_Mod::B # ⟶ [1, 2, 3]
$ray_test_Mod::C # ⇒ ${dollar}hi
$ray_test_Mod::C # ↦ $hi
```

# DESCRIPTION

It's fine.

# LICENSE

© Yaroslav O. Kosmina
2023
END

# После прохождения должен появится файл t/ray_test_-mod.t и секция __END__ в lib/ray_test_Mod.pm
#my $ok = system "/usr/bin/perl -I$lib $liveman";
#ok !$ok, "ray";

use_ok "Liveman";

ok !-f TEST, "Is'nt test file";

Liveman->new->transforms;

ok -f TEST, "Is test file";

ok !-f "cover_db/coverage.html", "Is'nt cover file";

Liveman->new->tests;

ok -f "cover_db/coverage.html", "Is cover file";

my $pm = read_text PM;

is $pm, << 'END', 'File PM';
package ray_test_Mod;

our $A = 10;
our $B = [1, 2, 3];
our $C = "\$hi";

1;

__END__

=encoding utf-8

=head1 NAME

ray_test_Mod — тестовый модуль

=head1 SYNOPSIS

	use ray_test_Mod;
	
	$ray_test_Mod::A # -> 5+5
	$ray_test_Mod::B # --> [1, 2, 3]
	
	my $dollar = '$';
	$ray_test_Mod::C # => ${dollar}hi
	
	$ray_test_Mod::C # \> $hi
	
	
	$ray_test_Mod::A # → 5+5
	$ray_test_Mod::B # ⟶ [1, 2, 3]
	$ray_test_Mod::C # ⇒ ${dollar}hi
	$ray_test_Mod::C # ↦ $hi

=head1 DESCRIPTION

It's fine.

=head1 LICENSE

© Yaroslav O. Kosmina
2023
END

my $test = read_text TEST;

is $test, << 'END', 'File TEST';
use strict; use warnings; use utf8; use open qw/:std :utf8/; use Test::More 0.98; # # NAME
# 
# ray_test_Mod — тестовый модуль
# 
# # SYNOPSIS
# 

subtest 'SYNOPSIS' => sub { 	use ray_test_Mod;
	
	is scalar do {$ray_test_Mod::A}, scalar do{5+5}, '$ray_test_Mod::A # -> 5+5';
	is_deeply scalar do {$ray_test_Mod::B}, scalar do {[1, 2, 3]}, '$ray_test_Mod::B # --> [1, 2, 3]';
	
	my $dollar = '$';
	is scalar do {$ray_test_Mod::C}, "${dollar}hi", '$ray_test_Mod::C # => ${dollar}hi';
	
	is scalar do {$ray_test_Mod::C}, '$hi', '$ray_test_Mod::C # \> $hi';
	
	
	is scalar do {$ray_test_Mod::A}, scalar do{5+5}, '$ray_test_Mod::A # → 5+5';
	is_deeply scalar do {$ray_test_Mod::B}, scalar do {[1, 2, 3]}, '$ray_test_Mod::B # ⟶ [1, 2, 3]';
	is scalar do {$ray_test_Mod::C}, "${dollar}hi", '$ray_test_Mod::C # ⇒ ${dollar}hi';
	is scalar do {$ray_test_Mod::C}, '$hi', '$ray_test_Mod::C # ↦ $hi';

# 
# # DESCRIPTION
# 
# It's fine.
# 
# # LICENSE
# 
# © Yaroslav O. Kosmina
# 2023

	done_testing;
};

done_testing;
END


# Добавляем файл:
write_text MD2, << 'END';
=SUBJECT

```js
console.log("js")
```

```perl
10 # -> 10
```
END

my $count = Liveman->new->transforms->{count};

is $count, 1, "Old files not transition";
ok -e PM2, "Is pm2";
ok -e TEST2, "Is test2";

is Liveman->new(files => [MD2])->transforms->{count}, 0, "Old file in list";

is Liveman->new(files => [])->transforms->{count}, 0, "Old files not transforms";

# Меняем время модификации файла:
sleep 1;
open my $f, ">>", MD2; print $f "\n"; close $f;

is Liveman->new(files => [MD2])->transforms->{count}, 1, "Young file";

# Принудительная трансформация
is Liveman->new->transform(MD2)->{count}, 1, "Need transform";

#system "rm -fr ${\DIR}";

done_testing;
