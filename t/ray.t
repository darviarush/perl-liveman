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
};

my $ray = Cwd::abs_path("script/ray");
my $lib = Cwd::abs_path("lib");

-d DIR or do { mkdir DIR, 0755 or die DIR . " mkdir: $!" };
chdir DIR or die DIR . " chdir: $!";

# Должно быть 2 файла: lib/ray_test_Mod.md и lib/ray_test_Mod.pm

mkdir "lib", 0755;

write_text PM, << 'END';
package ray_test_Mod;

our A = 10;
our B = [1, 2, 3];
our C = "\$hi";

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
2022
END

# После прохождения должен появится файл t/ray_test_-mod.t и секция __END__ в lib/ray_test_Mod.pm
{
    local @ARGV = ();
    unshift @INC, 'lib';
    require $ray;
}

ok -f TEST, "Is test file";
ok -f "cover_db/coverage.html", "Is cover file";

my $pm = read_text PM;
is $pm, << 'END', 'File PM';
package ray_test_Mod;

our A = 10;
our B = [1, 2, 3];
our C = "\$hi";

1;

__END__
END

my $test = read_text TEST;
is $test, << 'END', 'File TEST';
123
END


done_testing;
