# VERSION

0.01

# NAME

liveman - "живой мануал". Утилита для преобразования `lib/**.md`-файлов в файлы тестов `t/**.t` и документацию (`POD`), которая помещается в соответствующий модуль `lib/**.pm`

# SYNOPSIS

```sh
cd 'каталог проекта'

liveman -o
```

# DESCRIPTION

Проблема современных проектов в том, что документация оторвана от тестирования.
Это означает, что примеры в документации могут быть нерабочими, а сама документация — отставать от кода.

Метод одновременного документирования и тестирования решает данную проблему.

Для документирования выбран формат `markdown`, как наиболее лёгкий для ввода и широкораспространённый. 
Секции кода `perl`, описанные в нём, транслируются в тест. А докуметация транслируется в `POD` и добавляется в секцию `__END__` модуля perl.

Другими словами утилита `liveman` преобразует `lib/**.md`-файлы в файлы тестов (`t/**.t`) и документацию, которая помещается в соответствующий модуль `lib/**.pm`. 
И сразу же запускает тесты с покрытием.

Покрытие можно посмотреть в файле cover_db/coverage.html.

Примечание: в `.gitignore` лучше сразу же поместить `cover_db/`.


# EXAMPLE

Есть файлы:

`lib/ray_test_Mod.pm`:

```perl
	package ray_test_Mod;

	our $A = 10;
	our $B = [1, 2, 3];
	our $C = "\$hi";

	1;
```

`lib/ray_test_Mod.md`:
	
```perl
# NAME

ray_test_Mod — тестовый модуль

# SYNOPSIS

\```perl
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
\```
```

Запускаем **liveman**:

```sh
liveman -o
```
	
Эта команда модифицирует `pm`-файл:

`lib/ray_test_Mod.pm`:

```perl
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
```
	
И создаст тест:

`t/ray_test_-mod.t`:

```perl
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
```

А так же запустит его с покрытием:

```
Deleting database /home/dart/__/@lib/perl-liveman/cover_db
( PASSED )  job  1    t/ray_test_-mod.t

                                Yath Result Summary
-----------------------------------------------------------------------------------
     File Count: 1
Assertion Count: 8
      Wall Time: 2.88 seconds
       CPU Time: 5.29 seconds (usr: 0.26s | sys: 0.04s | cusr: 4.08s | csys: 0.91s)
      CPU Usage: 183%
    -->  Result: PASSED  <--

Reading database from /home/dart/__/@lib/perl-liveman/cover_db


-------------------- ------ ------ ------ ------ ------ ------
File                  stmt   bran   cond    sub   time  total
-------------------- ------ ------ ------ ------ ------ ------
lib/ray_test_Mod.pm   95.9   79.5   85.7  100.0  100.0   91.9
Total                 95.9   79.5   85.7  100.0  100.0   91.9
-------------------- ------ ------ ------ ------ ------ ------


HTML output written to /tmp/ray-test/cover_db/coverage.html
```

Опция `-o` откроет покрытие в браузере (т.е. файл покрытия: cover_db/coverage.html).

# LICENSE

Copyright (C) Yaroslav O. Kosmina.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Yaroslav O. Kosmina <darviarush@mail.ru>
