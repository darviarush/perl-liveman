package Liveman::CoverBadge;

use common::sense;
use Badge::Simple qw/badge/;
use File::Basename qw/dirname/;
use File::Slurper qw/read_text/;
use File::Path qw/mkpath/;

# Конструктор
sub new {
	my $cls = shift;
	
	bless {
        coverage_html => 'cover_db/coverage.html',
        badge_path => 'doc/badges/total.svg',
        @_
	}, ref $cls || $cls;
}

# Создаёт svg
sub svg {
	my ($self, $percentage) = @_;

    my $color = $percentage >= 90 ? 'green' :
                $percentage >= 80 ? 'yellowgreen' :
                $percentage >= 70 ? 'yellow' : 'red';

    badge(left => "coverage", right => "$percentage%", color => $color)
}

# Загружает покрытие из отчёта html
sub load {
	my ($self) = @_;
	
    my $report = read_text $self->{coverage_html};

    ($self->{coverage}) =  $report =~ m!(\d+(?:\.\d+)?)\s*</td>\s*</tr>\s*</tfoot>!s;

    $self
}

# Сохраняет бэйдж
sub save {
	my ($self) = @_;

	mkpath dirname $self->{badge_path};
	
    $self->svg($self->{coverage})->toFile($self->{badge_path});

    $self
}

1;