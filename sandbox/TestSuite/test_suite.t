#!/usr/bin/perl

use strict;
use warnings;
use 5.010;
use Test::More;
use Data::Dumper;
use DBI;
use List::Util qw(first);

unless (eval { require SQL::Translator }) {
    plan(skip_all => 'SQL::Translator is required for this test');
}



require Artist;
require Label;
require Rating;
require CD;
require ArtistCD;
require CDSong;
require Song;
require Cvs;

unlink 'test_suite.db';

system 'sqlite3 test_suite.db < test_suite.sqlite.sql';

my $dbh = DBI->connect("dbi:SQLite:test_suite.db", "", "");

Artist->dbh($dbh);

{
    pass '~ Populating database ~';
    ok my $label = Label->new(name => 'EMI');
    ok $label->save();

    ok my $artist1 = Artist->new(name => 'Metallica', label_id => $label->id);
    ok $artist1->save();

    ok(Cvs->new(artist_name => $artist1->name)->save());

    ok my $artist2 = Artist->new(name => 'U2', label_id => $label->id);
    ok $artist2->save();

    ok(Cvs->new(artist_name => $artist2->name)->save());

    ok my $rating = Rating->new();
    ok !$rating->is_defined;

    ok $rating->insert({ range => 1, artist_id => $artist1->id });
    ok $rating->insert({ range => 2, artist_id => $artist2->id });

    ok my $album1 = CD->new(title => 'Load', release => '1996', label_id => $label->id);
    ok $album1->save();

    ok my $album2 = CD->new(title => 'Reload', release => '1992', label_id => $label->id);
    ok $album2->save();

    ok my $album3 = CD->new(title => 'Boy', release => '1980', label_id => $label->id);
    ok $album3->save();

    ok my $album4 = CD->new(title => 'Zooropa', release => '1993', label_id => $label->id);
    ok $album4->save();

    ok( ArtistCD->new(artist_id => $artist1->id, cd_id => $album1->id)->save() );
    ok( ArtistCD->new(artist_id => $artist1->id, cd_id => $album2->id)->save() );
    ok( ArtistCD->new(artist_id => $artist2->id, cd_id => $album3->id)->save() );
    ok( ArtistCD->new(artist_id => $artist2->id, cd_id => $album4->id)->save() );

    ok my $song1 = Song->new(title => '2x4');
    ok $song1->save();
    ok my $song2 = Song->new(title => 'Mama Said');
    ok $song2->save();

    ok( CDSong->new(song_id => $song1->id, cd_id => $album1->id)->save() );
    ok( CDSong->new(song_id => $song1->id, cd_id => $album1->id)->save() );
};
{
    pass '~ cd ~';
    ok my $album = CD->find({ title => 'Zooropa' })->fetch;
    is $album->title, 'Zooropa';

    ok $album = CD->find({ title => 'Zooropa', release => '1993' })->fetch;
    is $album->title, 'Zooropa';

    my $res = CD->find('id > ? order by title', 1);
    ok my @discs = CD->find('id > ? order by title', 1)->fetch();
    is $discs[0]->title, 'Boy';

    my $id_album = $album->id;
    ok $album->title('FooBarBaz');
    is $album->title, 'FooBarBaz';
    ok $album->save();

    $album = CD->find($id_album)->fetch();
    is $album->title, 'FooBarBaz';

    $album->title('Zooropa');
    $album->save();

    is $album->release, '1993';
    ok $album->increment('release')->save();

    is $album->release, '1994';

    my $a1 = CD->get($album->id);
    is $a1->release, '1994';

    ok $album->decrement('release')->save();
    is $album->release, '1993';

    my $a2 = CD->get($album->id);
    is $a2->release, '1993';

    ok $album->increment('title');
    is $album->title, 1;

    $album->title('Zooropa');
    ok $album->decrement('title');
    is $album->title, -1;

    $album->title('Zooropa');

    $album->increment('release', 'title');
    is $album->release, '1994';
    is $album->title, 1;

    $album->decrement('release', 'title');
    is $album->release, '1993';
    is $album->title, 0;
}

{
    pass '~ artist <-> label ~';
    ok my $metallica = Artist->find({ name => 'Metallica' })->fetch;
    is $metallica->name, 'Metallica';
    is $metallica->label->name, 'EMI';

    ok my $u2 = Artist->find({ name => 'U2' })->fetch;
    is $u2->name, 'U2';
    is $u2->label->name, 'EMI';

    ok my $label = Label->find({ name => 'EMI' })->fetch;
    is $label->name, 'EMI';
    my @artists = $label->artists->fetch();
    is scalar @artists, 2;

    for my $artist (@artists) {
        ok scalar first {$artist->name eq $_} ('Metallica', 'U2');
    }

    ### Another ways for search
    ok my $a1 = Artist->find($metallica->id)->fetch;
    is $a1->name, 'Metallica';

    ok my ($a2, $a3) = Artist->find([$metallica->id, $u2->id])->fetch;
    is $a2->name, 'Metallica';
    is $a3->name, 'U2';

    ok my $a4 = Artist->find('name = ?', 'U2')->fetch;
    is $a4->name, 'U2';

    is $metallica->label->name, 'EMI';
    ok $metallica->label->name('Foo');
    is $metallica->label->name, 'Foo';
    ok $metallica->label->save();

    ok $u2 = Artist->find({ name => 'U2' })->fetch;
    is $u2->name, 'U2';
    is $u2->label->name, 'Foo';

    $u2->label->name('EMI');
    $u2->label->save;
};
{
    pass '~ artist <-> rating ~';
    ok my $artist = Artist->find({ name => 'Metallica' })->fetch;
    ok $artist->rating->range;

    #eval { ok my $r = Rating->find(1) };
    ok my $r = Rating->find({ range => 1 })->fetch;
    ok $r->is_defined;
    is $r->artist->name, 'Metallica';

    ok !Rating->find({ range => 3 })->fetch;
}

{
    pass '~ artist <- arist_cd -> cd ~';
    ok my $artist = Artist->find({ name => 'Metallica' })->fetch;

    ok my @albums = $artist->albums->fetch();
    is scalar @albums, 2;

    ok my $album = CD->find({ title => 'Boy' })->fetch;
    ok my ($u2) = $album->artists->fetch(1);
    is $u2->name, 'U2';
}

{
    pass '~ song <- cd_song -> cd ~';
    ok my $album = CD->find({ title => 'Load' })->fetch;
    ok my @songs = $album->songs->fetch;
    is scalar @songs, 2;

    ok my $song = Song->find({ title => '2x4' })->fetch(1);
    ok my $cd = $song->albums->fetch(1);
    is $cd->title, 'Load';
}

{
    pass '~ new fetch ~';
    ok my @cd = CD->find('id > ?', 1)->order_by('title', 'id')->fetch();
    ok @cd = CD->find('id > ?', 2)->fetch();
    ok @cd = CD->find({ title => 'Load' })->fetch();
    ok scalar @cd == 1;

    ok @cd = CD->find([1, 2, 3])->fetch();
    ok scalar @cd == 3;

    ok my $cd = CD->find(1)->fetch;
    is $cd->title, 'Load';
}

#{
#    pass '~ use_smart_saving ~';
#
#    ok my @a = Artist->find('id >= ?', 1)->fetch();
#    my $metallica = shift @a;
#    ok $metallica->save;
#    ok $metallica->_smart_saving_used;
#    ok $metallica->{snapshoot};
#}

{
    pass '~ ordering ~';
    my $artists_find = Artist->find('id != ?', 100)->order_by('name')->desc(1);


    is $artists_find->{prep_asc_desc}, 1, 'desc';
    ok ref $artists_find->{prep_order_by};
    is ref $artists_find->{prep_order_by}, 'ARRAY';
    is $artists_find->{prep_order_by}[0], '"name" DESC';

    ok $artists_find->fetch, 'fetch 1';

    $artists_find = Artist->find('id != ?', 100)->order_by('name', 'label_id')->desc(1)->order_by('id')->asc;

    ok $artists_find->fetch, 'fetch 2';
}

{
    pass '~ limit, offset ~';
    my @artists = Artist->find()->limit(1)->fetch;
    is scalar @artists, 1;

    my $a = Artist->find()->limit(1)->offset(1)->fetch;
    is $a->name, 'U2';
}

{
    pass '~ fetch ~';

    my $find = CD->find;

    my $find2 = CD->find;
    my @cd = $find2->fetch(3);
    is scalar @cd, 3;
    @cd = $find2->fetch(2);
    is scalar @cd, 2;
}

{
    pass '~ new rel system ~';
    my $artist = Artist->find({ name => 'U2' })->fetch;
    is $artist->name, 'U2';


    ok $artist->label;
    is $artist->label->name, 'EMI', 'chain works well';

    ok $artist->label(Label->new({name => 'FooBarBaz'})->save)->save;
    is $artist->label->name, 'FooBarBaz';

    my $artist_again = Artist->find({ name => 'U2' })->fetch;
    is $artist_again->label->name, 'FooBarBaz';

    my $metallica = Artist->find({ name => 'Metallica' })->fetch;
    is $metallica->label->name, 'EMI';

}


{
    pass '~ testing "only" ~';
    my $cd = CD->find->only('title')->limit(1)->fetch;
    ok exists $cd->{title};
    ok $cd->title;
    ok !exists $cd->{release};
    ok !$cd->release;

    ok defined $cd->id;
}

{
    pass '~ read only ~';
    my $cd = CD->find(1)->fetch({ read_only => 1 });
    $cd->title('Foo');
    eval { $cd->save };
    ok $@;
    ok $@ =~ m/^Object is read-only/i;
}

{
    pass '~ count ~';
    is(CD->find->count(), 4);
    is(CD->find({ title => 'Boy' })->count, 1);
    is(CD->find('id > ?', 1)->count, 3);
}

{
    pass '~ first && last ~';
    ok my $artist = Artist->find->first;
    is $artist->name, 'Metallica';
    ok $artist = Artist->find->last;
    is $artist->name, 'U2';
    ok defined $artist->label_id;

    ok $artist = Artist->find->only('name')->first;
    ok defined $artist->name;
    ok !defined $artist->label_id;

    ok my @artists = Artist->find->first(2);
    is scalar @artists, 2;

    is $artists[0]->name, 'Metallica';
    is $artists[1]->name, 'U2';

    ok @artists = Artist->find->last(2);
    is scalar @artists, 2;

    is $artists[0]->name, 'U2';
    is $artists[1]->name, 'Metallica';
}

{
    pass '~ exists ~';
    ok( Artist->find('name = ?', 'U2')->exists );
    ok( Artist->find({ name => 'U2' })->exists );
    ok( Artist->find(2)->exists );

    ok( !Artist->find('name = ?', 'Blink-182')->exists );
    ok( !Artist->find({ name => 'Blink-182' })->exists );
    ok( !Artist->find(100)->exists );

    my $artist = Artist->new({ name => 'U2' });

    ok $artist->exists;

    $artist = Artist->new({ name => 'Blink-182' });
    ok !$artist->exists;
}

{
    pass '~ cvs ~';
    ok my @cvs = Cvs->find()->fetch();
    is scalar @cvs, 2;
}

{

    pass '~ generics ~';
    my $artist = Artist->get(1);

    ok $artist->cvs->fetch();
    my $cvs = Cvs->get(1);
    ok $cvs->artist->fetch();
}

{
    pass '~ to_sql ~';

    ok(Artist->find({ name => 'Metallica' })->order_by('name')->limit(10)->to_sql, 'to_sql, scalar');
    ok my @list = Artist->find('name = ?', 'Metallica')->to_sql, 'to_sql, list';
    is scalar @list, 2, 'list size is 2';
    is $list[1][0], 'Metallica', 'bind is good'
}

{
    pass '~ left outer joins ~';

    my $artist = Artist->find('artist.name = ?', 'Metallica')->with('label', 'albums')->fetch;
    is $artist->name, 'Metallica';
    ok exists $artist->{relation_instance_label}, 'joided';
    ok ! exists $artist->{relation_instance_albums}, 'not joined';
    ok $artist->label->name;

    $artist = Artist->find('artist.name = ?', 'Metallica')->left_join('label')->fetch;
    ok exists $artist->{relation_instance_label};
}
{
    pass '~ where-in request ~';

    my @artists = Artist->find({ name => ['Metallica', 'U2'] })->fetch;
    is scalar @artists, 2;

    my @cds = CD->find({ id => [1, 2] })->fetch;
    is scalar @cds, 2;

    my $cnt = Artist->count({ name => ['Metallica', 'U2'] });
    is $cnt, 2;
}

{
    pass '~ skip empty params hash ~';

    my @cds1 = CD->find({})->fetch;
    my @cds2 = CD->find()->fetch;

    is scalar @cds1, scalar @cds2;

    my $cnt1 = CD->count();
    my $cnt2 = CD->count({});

    is $cnt1, $cnt2;
}

{
    pass '~ update ~';

    my $cv = Cvs->find->first;

    ok $cv->update({ n_golds => 10, n_platinums => 10, n_grammies => 10 });
    ok $cv->save;

    my $cv2 = Cvs->get($cv->id);
    is $cv2->n_grammies, 10;
    is $cv2->n_platinums, 10;
    is $cv2->n_golds, 10;
}

{
    pass '~ abstract ~';

    my $find = Artist->find;
    $find->abstract({
        order_by => { column => 'name' },
        limit => 10,
        offset => 1,
        desc => 1
    });
    my @artists = $find->fetch;
}




done_testing;
