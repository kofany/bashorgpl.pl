use strict;
use warnings;
use LWP::UserAgent;
use HTML::Entities;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.6";
%IRSSI = (
    authors     => 'Jerzy (kofany) Dabrowski',
    contact     => 'j@dabrowski.biz',
    name        => 'BashOrgScraper',
    description => 'Scrapuje cytaty z bash.org.pl i formatuje je dla IRC',
    license     => 'GNU GPL',
    changed     => '07.12.2023',
);

my $last_call_time = 0;
my $call_interval = 10; # czas w sekundach między kolejnymi wywołaniami

Irssi::signal_add('message public', 'handle_public');
sub get_random_bash_quote {
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get('http://bash.org.pl/random/');

    if ($response->is_success) {
        my $content = $response->decoded_content;
        my $quote_number;
        my $date = "nieznana data";  # Domyślna wartość dla daty

        if ($content =~ m{<a class="qid click" href="/(\d+)/">#\d+</a>}s) {
            $quote_number = $1;  # Pobiera numer cytatu
        }
        if ($content =~ m{<div class="right">\s*(.*?)\s*</div>}s) {
            $date = $1;  # Pobiera datę cytatu
        }
        if ($content =~ m{<div class="quote post-content post-body">(.*?)</div>}s) {
            my $quote = $1;
            $quote =~ s/<br\s*\/?>/\n/gi;  # Zamienia znaczniki <br> na nowe linie
            $quote =~ s/<[^>]*>//g;  # Usuwa pozostałe tagi HTML
            $quote = decode_entities($quote);  # Konwertuje encje HTML na znaki
            $quote =~ s/^\s+|\s+$//g;  # Usuwa białe znaki z początku i końca linii
            $quote =~ s/\t/    /g;  # Zamienia tabulatory na spacje
            return ($quote, $quote_number, $date);
        }
    }
    return ("Nie udało się pobrać cytatu.", "", $date);
}

sub get_quote_by_number {
    my ($quote_number) = @_;
    my $ua = LWP::UserAgent->new;
    my $url = "http://bash.org.pl/$quote_number/";
    my $response = $ua->get($url);

    if ($response->is_success) {
        my $content = $response->decoded_content;
        my $date = "nieznana data";  # Domyślna wartość dla daty

        if ($content =~ m{<div class="right">\s*(.*?)\s*</div>}s) {
            $date = $1;  # Pobiera datę cytatu
        }
        if ($content =~ m{<div class="quote post-content post-body">(.*?)</div>}s) {
            my $quote = $1;
            $quote =~ s/<br\s*\/?>/\n/gi;
            $quote =~ s/<[^>]*>//g;
            $quote = decode_entities($quote);
            $quote =~ s/^\s+|\s+$//g;
            $quote =~ s/\t/    /g;
            return ($quote, $date);
        }
    }
    return ("Nie udało się pobrać cytatu o numerze $quote_number.", "");
}

sub send_quote_in_parts {
    my ($server, $target, $quote, $quote_number, $date) = @_;
    my @lines = split /\n/, $quote;

    # Wysyłanie nagłówka z numerem i datą cytatu
    $server->command("msg $target [ cytat nr: #$quote_number | Dodano: $date ]");

    foreach my $line (@lines) {
        if ($line =~ /^\s*$/) {
            next;  # Pomija puste linie
        }
        $server->command("msg $target $line");
    }

    # Wysyłanie stopki z linkiem do cytatu
    $server->command("msg $target [ url http://bash.org.pl/$quote_number/ ]");
}

sub handle_public {
    my ($server, $msg, $nick, $address, $target) = @_;
    if ($msg eq "!bash") {
        if (time - $last_call_time > $call_interval) {
            $last_call_time = time;
            my ($quote, $quote_number, $date) = get_random_bash_quote();
            send_quote_in_parts($server, $target, $quote, $quote_number, $date);
        } else {
            $server->command("msg $target Zaczekaj chwilę przed kolejnym użyciem !bash");
        }
    } elsif ($msg =~ /^!cytat (\d+)$/) {
        my $quote_number = $1;
        if (time - $last_call_time > $call_interval) {
            $last_call_time = time;
            my ($quote, $date) = get_quote_by_number($quote_number);
            send_quote_in_parts($server, $target, $quote, $quote_number, $date);
        } else {
            $server->command("msg $target Zaczekaj chwilę przed kolejnym użyciem !cytat");
        }
    }
}

Irssi::command_bind('bash', 'cmd_bash');

sub cmd_bash {
    my ($data, $server, $witem) = @_;
    if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY")) {
        if (time - $last_call_time > $call_interval) {
            $last_call_time = time;
            my $quote = get_random_bash_quote();
            send_quote_in_parts($server, $witem->{name}, $quote);
        } else {
            $witem->command("MSG ".$witem->{name}." Zaczekaj chwilę przed kolejnym użyciem !bash");
        }
    }
}
