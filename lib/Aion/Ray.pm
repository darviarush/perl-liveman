package Aion::Ray;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use Devel::Cover;


# Конструктор
sub new {
    my $cls = shift;
    bless {@_}, $cls
}

# Трансформирует md-файл в тест и документацию
sub transform {
    my ($self) = @_;
    open my $f, "<:utf8", $self->{file} or die "$self->{file}: $!";

    while(<$f>) {

    }

    close $f;
    $self
}

# Запустить тесты
sub tests {
    my ($self) = @_;
    
}

1;
__END__

=encoding utf-8

=head1 NAME

Aion::Ray - It's new $module

=head1 SYNOPSIS

    use Aion::Ray;

=head1 DESCRIPTION

Aion::Ray is ...

=head1 LICENSE

Copyright (C) Yaroslav O. Kosmina.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Yaroslav O. Kosmina E<lt>darviarush@mail.ruE<gt>

=cut

