package CV;

use strict;
use warnings;
use 5.010;

use lib '../../lib';
use base 'ActiveRecord::Simple';

__PACKAGE__->table_name('cv');
__PACKAGE__->columns('id', 'artist_name', 'n_grammies', 'n_platinums', 'n_golds');
__PACKAGE__->primary_key('id');

__PACKAGE__->generic(artist => 'Artist', { artist_name => 'name' });


1;
