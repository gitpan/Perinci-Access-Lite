package Perinci::Access::Lite;

our $DATE = '2014-09-03'; # DATE
our $VERSION = '0.01'; # VERSION

use 5.010001;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
}

# copy-pasted from SHARYANTO::Package::Util
sub __package_exists {
    no strict 'refs';

    my $pkg = shift;

    return unless $pkg =~ /\A\w+(::\w+)*\z/;
    if ($pkg =~ s/::(\w+)\z//) {
        return !!${$pkg . "::"}{$1 . "::"};
    } else {
        return !!$::{$pkg . "::"};
    }
}

sub request {
    my ($self, $action, $url, $extra) = @_;

    $extra //= {};

    if ($url =~ m!\A(?:pl:)?/(\w+(?:/\w+)*)/(\w*)\z!) {
        my ($mod, $func) = ($1, $2);
        # skip if package already exists, e.g. 'main'
        require "$mod.pm" unless __package_exists($mod);
        $mod =~ s!/!::!g;

        if ($action eq 'meta' || $action eq 'call') {
            my $meta;
            {
                no strict 'refs';
                if (length $func) {
                    $meta = ${"$mod\::SPEC"}{$func}
                        or return [500, "No metadata for '$url'"];
                } else {
                    $meta = ${"$mod\::SPEC"}{':package'} // {v=>1.1};
                }
                $meta->{entity_v}    //= ${"$mod\::VERSION"};
                $meta->{entity_date} //= ${"$mod\::DATE"};
            }

            require Perinci::Sub::Normalize;
            $meta = Perinci::Sub::Normalize::normalize_function_metadata($meta);
            return [200, "OK", $meta] if $action eq 'meta';

            # convert args
            my $args = $extra->{args} // {};
            my $aa = $meta->{args_as} // 'hash';
            my @args;
            if ($aa =~ /array/) {
                require Perinci::Sub::ConvertArgs::Array;
                my $convres = Perinci::Sub::ConvertArgs::Array::convert_args_to_array(
                    args => $args, meta => $meta,
                );
                return $convres unless $convres->[0] == 200;
                if ($aa =~ /ref/) {
                    @args = ($convres->[2]);
                } else {
                    @args = @{ $convres->[2] };
                }
            } elsif ($aa eq 'hashref') {
                @args = ({ %$args });
            } else {
                # hash
                @args = %$args;
            }

            # call!
            my $res;
            {
                no strict 'refs';
                $res = &{"$mod\::$func"}(@args);
            }

            # add envelope
            if ($meta->{result_naked}) {
                $res = [200, "OK (envelope added by ".__PACKAGE__.")", $res];
            }
            return $res;

        } else {
            return [502, "Unknown/unsupported action '$action'"];
        }
    } elsif (0 && $url =~ m!\Ahttps?:/(/?)!i) {
        my $is_unix = !$1;
    } else {
        return [502, "Unsupported scheme or bad URL '$url'"];
    }
}

1;
# ABSTRACT: A lightweight Riap client library

__END__

=pod

=encoding UTF-8

=head1 NAME

Perinci::Access::Lite - A lightweight Riap client library

=head1 VERSION

This document describes version 0.01 of Perinci::Access::Lite (from Perl distribution Perinci-Access-Lite), released on 2014-09-03.

=head1 DESCRIPTION

This module is a lightweight alternative to L<Perinci::Access>. It has less
prerequisites but does fewer things. Differences with Perinci::Access:

=over

=item * No wrapping, no argument checking

For 'pl' or schemeless URL, no wrapping (L<Perinci::Sub::Wrapper>) is done, only
normalization (using L<Perinci::Sub::Normalize>).

=item * No transaction or logging support

=item * No support for some schemes

This includes: Riap::Simple over pipe/TCP socket.

=back

=head1 METHODS

=head2 new => obj

=head2 $pa->request($action, $url, $extra) => hash

=head1 SEE ALSO

L<Perinci::Access>

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Perinci-Access-Lite>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Perinci-Access-Lite>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Perinci-Access-Lite>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
