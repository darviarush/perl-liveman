[![Actions Status](https://github.com/darviarush/perl-liveman/actions/workflows/test.yml/badge.svg)](https://github.com/darviarush/perl-liveman/actions)
$pod!smn;
    write\_text $pm, $module;

    $self->{count}++;

    $self
}

\# Запустить тесты
sub tests {
    my ($self) = @\_;

    if($self->{files}) {
        local $, = " ";
        $self->{exitcode} = system "yath test -j4 @{$self->{files}}";
        return $self;
    }

    system "cover -delete";
    $self->{exitcode} = system "yath test -j4 --cover" and return $self;
    system "cover -report html_basic";
    system "opera cover_db/coverage.html || xdg-open cover_db/coverage.html" if $self->{open};
    return $self;
}

1;
\_\_END\_\_

# NAME

Liveman - markdown compiller to test and pod.

# SYNOPSIS

    use Liveman;

    my $liveman = Liveman->new;

    # compile lib/Example.md file to t/example.t and added pod to lib/Example.pm
    $liveman->transform("lib/Example.md");

    # compile all lib/**.md files
    $liveman->transforms;

    # start tests with yath
    $liveman->tests;

    # limit liveman to these files for operations transforms and tests (without cover)
    my $liveman = Liveman->new(files => ["lib/Example1.md", "lib/Examples/Example2.md"]);

# DESCRIPTION

The problem with modern projects is that the documentation is disconnected from testing.
This means that the examples in the documentation may not work, and the documentation itself may lag behind the code.

Liveman compile lib/\*\*.md files to t/\*\*.t files
and it added pod-documentation to section \_\_END\_\_ to lib/\*\*.pm files.

Use `liveman` command for compile the documentation to the tests in catalog of your project and starts the tests:

    liveman
        

# EXAMPLE

Is files:

lib/ray\_test\_Mod.pm:

        package ray_test_Mod;

        our $A = 10;
        our $B = [1, 2, 3];
        our $C = "\$hi";

        1;

lib/ray\_test\_Mod.md:

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

Start `liveman`:

        liveman -o
        

This command modify `pm`-file:

lib/ray\_test\_Mod.pm:

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

        

And this command make test:

t/ray\_test\_-mod.t:

        use strict; use warnings; use utf8; use open qw/:std :utf8/; use Test::More 0.98; # # NAME
        # 
        # ray_test_Mod — тестовый модуль
        # 
        # # SYNOPSIS
        # 

        subtest 'SYNOPSIS' => sub {     use ray_test_Mod;
                
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

Run it with coverage.

Option `-o` open coverage in browser (coverage file: cover\_db/coverage.html).

# LICENSE

⚖ **GPLv3**

# AUTHOR

Yaroslav O. Kosmina <darviarush@mail.ru>
