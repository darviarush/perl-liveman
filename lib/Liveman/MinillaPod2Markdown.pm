package Liveman::MinillaPod2Markdown;
# Обманка для Minilla, чтобы скопировать Module в README.md

use parent qw/Pod::Markdown/;

sub new { bless {}, __PACKAGE__ }

sub parse_from_file {
    my ($self, $path) = @_;
    $self->{path} = $path =~ s!\.pm$!.md!r;
    $self
}

sub as_markdown {
    my ($self) = @_;
    open my $f, "<:utf8", $self->{path} or die "Not open file $self->{path}!";
    read $f, my $buf, -s $f;
    close $f;
    $buf
}

1;

__END__

=encoding utf-8

=head1 NAME

Liveman::MinillaPod2Markdown - bung for Minilla. It not make README.md

=head1 SYNOPSIS

	use Liveman::MinillaPod2Markdown;
	
	my $mark = Liveman::MinillaPod2Markdown->new;
	
	$mark->isa("Pod::Markdown")  # -> 1
	
	open my $f, ">", "X.md" or die "X.md: $!"; print $f "hi!"; close $f;
	
	$mark->parse_from_file("X.pm");
	$mark->{path}  # => X.md
	
	$mark->as_markdown  # => hi!

=head1 DESCRIPION

Add C<markdown_maker = "Liveman::MinillaPod2Markdown"> to C<minil.toml>, and Minilla do'nt make README.md.

=head1 SUBROUTINES

=head2 as_markdown ()

The bung.

=head2 new ()

The constructor.

=head2 parse_from_file ($path)

The bung.

=head1 INSTALL

For install this module in your system run next LL<https://metacpan.org/pod/App::cpm>:

	sudo cpm install -gvv Liveman::MinillaPod2Markdown

=head1 AUTHOR

Yaroslav O. Kosmina LL<mailto:darviarush@mail.ru>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Liveman::MinillaPod2Markdown module is copyright © 2023 Yaroslav O. Kosmina. Rusland. All rights reserved.
