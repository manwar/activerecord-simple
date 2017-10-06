package ActiveRecord::Simple::Utils;

use strict;
use warnings;


sub quote_sql_stmt {
    my ($sql, $driver_name) = @_;

    return unless $sql && $driver_name;

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

sub class_to_table_name {
    my ($class_name) = @_;

    $class_name =~ s/.*:://;
    $class_name = lc $class_name;

    return $class_name;
}

sub is_numeric {
    my ($data_type) = @_;

    return unless $data_type;

    return grep { $data_type eq $_ } qw/integer bigint tinyint decimal smallint/;
}

1;