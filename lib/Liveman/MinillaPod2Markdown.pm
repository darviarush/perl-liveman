package Liveman::MinillaPod2Markdown;
# Обманка для Minilla, чтобы скопировать Module в README.md

use parent qw/Pod::Markdown/;

use File::Slurper qw/read_text write_text/;

sub new { bless {}, __PACKAGE__ }

sub parse_from_file {
    my ($self, $path) = @_;
    $self->{pm_path} = $path;
    $self->{path} = $path =~ s!\.pm$!.md!r;
    $self
}

sub as_markdown {
    my ($self) = @_;

    my $md = read_text $self->{path};
    my $pm = read_text $self->{pm_path};

    my $v = uc "version";
    my ($md_version) = $md =~ /^#[ \t]+$v\s+([\w.-]{1,32})\s/m;
    my ($pm_version) = $pm =~ /^our\s+\$$v\s*=\s*["']?([\w.-]{1,32})/m;
    my ($hd_version) = $pm =~ /^=head1[ \t]+VERSION\s+([\w.-]{1,32})\s/m;

    if(defined $pm_version and defined $md_version and $pm_version ne $md_version) {
        $md =~ s/(#[ \t]+$v\s+)[\w.-]{1,32}(\s)/$1$pm_version$2/;
        write_text $self->{path}, $md;
    }

    if(defined $pm_version and defined $hd_version and $pm_version ne $hd_version) {
        $pm =~ s/^(=head1[ \t]+VERSION\s+)[\w.-]{1,32}(\s)/$1$pm_version$2/m;
        write_text $self->{pm_path}, $pm;
    }

    $md =~ s/^!\w+:\w+\s+//;

    $md
}

1;

__END__

=encoding utf-8

=head1 NAME

Liveman :: Minillapod2markdown - a plug for minilla, which throws Lib/Mainmodule.md to Readme.md

=head1 SYNOPSIS

	use Liveman::MinillaPod2Markdown;
	
	my $mark = Liveman::MinillaPod2Markdown->new;
	
	$mark->isa("Pod::Markdown")  # -> 1
	
	use File::Slurper qw/write_text/;
	write_text "X.md", "hi!";
	write_text "X.pm", "our \$VERSION = 1.0;";
	
	$mark->parse_from_file("X.pm");
	$mark->{path}  # => X.md
	
	$mark->as_markdown  # => hi!

=head1 DESCRIPION

Add the C<Markdown_maker =" Liveman :: Minillapod2markdown "> Minil.tomlC<"Liveman: Minilla will not create> readme.mdC<from the POD-documenting of the main module, and will take from the same name next to the extension>*.MD`.

=head1 SUBROUTINES

=head2 as_markdown ()

Plug.

=head2 new ()

Constructor.

=head2 parse_from_file ($path)

Plug.

=head1 INSTALL

To install this module in your system, follow the following actions [command] (https://metacpan.org/pod/app:::

	sudo cpm install -gvv Liveman::MinillaPod2Markdown

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ I<* gplv3 *>

=head1 COPYRIGHT

The Liveman :: minillapod2markdown module is copyright © 2023 Yaroslav O. Kosmina. Rusland. All Rights Reserved.
