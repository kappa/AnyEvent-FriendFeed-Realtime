package AnyEvent::FriendFeed::Realtime;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use AnyEvent;
use AnyEvent::HTTP;
use JSON;
use MIME::Base64;
use URI;

sub new {
    my($class, %args) = @_;

    my $token;
    my $auth = MIME::Base64::encode( join(":", $args{username}, $args{remote_key}) );

    my $uri = URI->new("http://friendfeed.com/api/updates"); # initialize token
    $uri->query_form(token => $token, format => 'json');

    my $timer;
    my $long_poll; $long_poll = sub {
        http_get $uri, headers => { Authorization => "Basic $auth" },
            sub {
                my($body, $headers) = @_;
                my $res = JSON->new->decode($body);
                for my $entry (@{$res->{entries}}) {
                    ($args{on_entry} || sub {})->($entry);
                }

                if ($res->{update}) {
                    $token = $res->{update}{token};
                    $uri = URI->new("http://friendfeed.com/api/updates/$args{method}");
                    $uri->query_form(token => $token, format => 'json');
                    $timer = AnyEvent->timer(
                        after => $res->{update}{poll_interval},
                        cb => $long_poll,
                    );
                }
            }
        };

    $long_poll->();

    bless { _timer => $timer }, $class;
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

AnyEvent::FriendFeed::Realtime - Subscribe to FriendFeed Real-time API

=head1 SYNOPSIS

  use AnyEvent::FriendFeed::Realtime;

  my $client = AnyEvent::FriendFeed::Realtime->new(
      username   => $user,       # optional
      remote_key => $remote_key, # optional: https://friendfeed.com/account/api
      method     => "home",      # "user/NICKNAME/friends", "list/NICKNAME", "room/NICKNAME", "user/NICKNAME"
      on_update  => sub {
          my $entry = shift;
          # See http://code.google.com/p/friendfeed-api/wiki/ApiDocumentation for the data structure
      },
  );

=head1 DESCRIPTION

AnyEvent::FriendFeed::Realtime is an AnyEvent consumer that subscribes
to FriendFeed Real-time API via JSON long-poll.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<AnyEvent::HTTP>, L<AnyEvent::Twitter::Stream>, L<http://code.google.com/p/friendfeed-api/wiki/ApiDocumentation>

=cut
