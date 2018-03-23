# Copyright 2015 Catalyst IT
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>

use Modern::Perl;

use Test::More tests => 3;
use Test::MockModule;

use t::lib::Mocks;
use t::lib::TestBuilder;
use MARC::Record;

use Koha::SearchFields;

my $schema = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;

use_ok('Koha::SearchEngine::Elasticsearch');

subtest 'get_fixer_rules() tests' => sub {

    plan tests => 49;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'marcflavour', 'MARC21' );

    my @mappings;

    my $se = Test::MockModule->new( 'Koha::SearchEngine::Elasticsearch' );
    $se->mock( '_foreach_mapping', sub {
        my ($self, $sub ) = @_;

        foreach my $map ( @mappings ) {
            $sub->(
                $map->{name},
                $map->{type},
                $map->{facet},
                $map->{suggestible},
                $map->{sort},
                $map->{marc_type},
                $map->{marc_field}
            );
        }
    });

    my $see = Koha::SearchEngine::Elasticsearch->new({ index => 'biblios' });

    @mappings = (
        {
            name => 'author',
            type => 'string',
            facet => 1,
            suggestible => 1,
            sort => undef,
            marc_type => 'marc21',
            marc_field => '100a',
        },
        {
            name => 'author',
            type => 'string',
            facet => 1,
            suggestible => 1,
            sort => 1,
            marc_type => 'marc21',
            marc_field => '110a',
        },
    );

    $see->get_elasticsearch_mappings(); #sort_fields will call this and use the actual db values unless we call it first
    my $result = $see->get_fixer_rules();
    is( $result->[0], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{.$append', )});
    is( $result->[1], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__facet.$append', )});
    is( $result->[2], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__suggestion.input.$append')});
    is( $result->[3], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__sort.$append', )});
    is( $result->[4], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{.$append', )});
    is( $result->[5], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__facet.$append', )});
    is( $result->[6], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__suggestion.input.$append')});
    is( $result->[7], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__sort.$append', )});
    is( $result->[8], q{move_field(_id,es_id)});

    $mappings[0]->{type}  = 'boolean';
    $mappings[1]->{type}  = 'boolean';
    $result = $see->get_fixer_rules();
    is( $result->[0], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{.$append', )});
    is( $result->[1], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__facet.$append', )});
    is( $result->[2], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__suggestion.input.$append')});
    is( $result->[3], q{unless exists('} . $mappings[0]->{name} . q{') add_field('} . $mappings[0]->{name} . q{', 0) end});
    is( $result->[4], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__sort.$append', )});
    is( $result->[5], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{.$append', )});
    is( $result->[6], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__facet.$append', )});
    is( $result->[7], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__suggestion.input.$append')});
    is( $result->[8], q{unless exists('} . $mappings[1]->{name} . q{') add_field('} . $mappings[1]->{name} . q{', 0) end});
    is( $result->[9], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__sort.$append', )});
    is( $result->[10], q{move_field(_id,es_id)});

    $mappings[0]->{type}  = 'sum';
    $mappings[1]->{type}  = 'sum';
    $result = $see->get_fixer_rules();
    is( $result->[0], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{.$append', )});
    is( $result->[1], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__facet.$append', )});
    is( $result->[2], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__suggestion.input.$append')});
    is( $result->[3], q{sum('} . $mappings[0]->{name} . q{')});
    is( $result->[4], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__sort.$append', )});
    is( $result->[5], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{.$append', )});
    is( $result->[6], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__facet.$append', )});
    is( $result->[7], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__suggestion.input.$append')});
    is( $result->[8], q{sum('} . $mappings[1]->{name} . q{')});
    is( $result->[9], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__sort.$append', )});
    is( $result->[10], q{move_field(_id,es_id)});

    $mappings[0]->{type}  = 'string';
    $mappings[0]->{facet} = 0;
    $mappings[1]->{type}  = 'string';
    $mappings[1]->{facet} = 0;

    $result = $see->get_fixer_rules();
    is( $result->[0], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{.$append', )});
    is( $result->[1], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__suggestion.input.$append')});
    is( $result->[2], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__sort.$append', )});
    is( $result->[3], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{.$append', )});
    is( $result->[4], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__suggestion.input.$append')});
    is( $result->[5], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__sort.$append', )});
    is( $result->[6], q{move_field(_id,es_id)});

    $mappings[0]->{suggestible}  = 0;
    $mappings[1]->{suggestible}  = 0;

    $result = $see->get_fixer_rules();
    is( $result->[0], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{.$append', )});
    is( $result->[1], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{__sort.$append', )});
    is( $result->[2], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{.$append', )});
    is( $result->[3], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__sort.$append', )});
    is( $result->[4], q{move_field(_id,es_id)});

    $mappings[0]->{sort}  = 0;
    $mappings[1]->{sort}  = undef;

    $see->get_elasticsearch_mappings(); #sort_fields will call this and use the actual db values unless we call it first
    $result = $see->get_fixer_rules();
    is( $result->[0], q{marc_map('} . $mappings[0]->{marc_field} . q{','} . $mappings[0]->{name} . q{.$append', )});
    is( $result->[1], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{.$append', )});
    is( $result->[2], q{marc_map('} . $mappings[1]->{marc_field} . q{','} . $mappings[1]->{name} . q{__sort.$append', )});
    is( $result->[3], q{move_field(_id,es_id)});

    t::lib::Mocks::mock_preference( 'marcflavour', 'UNIMARC' );

    $result = $see->get_fixer_rules();
    is( $result->[0], q{move_field(_id,es_id)});
    is( $result->[1], undef, q{No mapping when marc_type doesn't match marchflavour} );

    $schema->storage->txn_rollback;

};

subtest 'get_facetable_fields() tests' => sub {

    plan tests => 15;

    $schema->storage->txn_begin;

    Koha::SearchFields->search()->delete;

    $builder->build({
        source => 'SearchField',
        value => {
            name => 'author',
            label => 'author',
            type => 'string',
            facet_order => undef
        }
    });
    $builder->build({
        source => 'SearchField',
        value => {
            name => 'holdingbranch',
            label => 'holdingbranch',
            type => 'string',
            facet_order => 1
        }
    });
    $builder->build({
        source => 'SearchField',
        value => {
            name => 'homebranch',
            label => 'homebranch',
            type => 'string',
            facet_order => 2
        }
    });
    $builder->build({
        source => 'SearchField',
        value => {
            name => 'itype',
            label => 'itype',
            type => 'string',
            facet_order => 3
        }
    });
    $builder->build({
        source => 'SearchField',
        value => {
            name => 'se',
            label => 'se',
            type => 'string',
            facet_order => 4
        }
    });
    $builder->build({
        source => 'SearchField',
        value => {
            name => 'su-geo',
            label => 'su-geo',
            type => 'string',
            facet_order => 5
        }
    });
    $builder->build({
        source => 'SearchField',
        value => {
            name => 'subject',
            label => 'subject',
            type => 'string',
            facet_order => 6
        }
    });
    $builder->build({
        source => 'SearchField',
        value => {
            name => 'not_facetable_field',
            label => 'not_facetable_field',
            type => 'string',
            facet_order => undef
        }
    });

    my @faceted_fields = Koha::SearchEngine::Elasticsearch->get_facetable_fields();
    is(scalar(@faceted_fields), 7);

    is($faceted_fields[0]->name, 'holdingbranch');
    is($faceted_fields[0]->facet_order, 1);
    is($faceted_fields[1]->name, 'homebranch');
    is($faceted_fields[1]->facet_order, 2);
    is($faceted_fields[2]->name, 'itype');
    is($faceted_fields[2]->facet_order, 3);
    is($faceted_fields[3]->name, 'se');
    is($faceted_fields[3]->facet_order, 4);
    is($faceted_fields[4]->name, 'su-geo');
    is($faceted_fields[4]->facet_order, 5);
    is($faceted_fields[5]->name, 'subject');
    is($faceted_fields[5]->facet_order, 6);
    is($faceted_fields[6]->name, 'author');
    ok(!$faceted_fields[6]->facet_order);


    $schema->storage->txn_rollback;
};
