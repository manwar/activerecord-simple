package ActiveRecord::Simple::Utils;

use strict;
use warnings;


sub quote_sql_stmt {
    my ($sql, $driver_name) = @_;

    return unless $sql && $driver_name;

    #my $driver_name = $self->dbh->{Driver}{Name};
    $driver_name //= 'Pg';
    my $quotes_map = {
        Pg => q/"/,
        mysql => q/`/,
        SQLite => q/`/,
    };
    my $quote = $quotes_map->{$driver_name};

    $sql =~ s/"/$quote/g;

    return $sql;
}

1;