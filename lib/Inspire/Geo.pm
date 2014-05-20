#
# Package to contain re-usable functions for the growing Inspire::Geo scripts.
#
# Author: Tom Ryder <tom@sanctum.geek.nz>
# Copyright: 2014 Inspire Net Limited
# Version: 1.3
# License: GPLv3
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#
# $Id$
#
package Inspire::Geo;

# Force me to write this properly
use strict;      # dpkg: perl-base
use warnings;    # dpkg: perl-base
use utf8;        # dpkg: perl-base
use autodie;     # dpkg: perl-modules

# Require at least Perl 5.10
use 5.010_001;

# Decree package version
our $VERSION = 1.3;

# Load required modules
use Carp;                                  # dpkg: perl-base
use English qw(-no_match_vars);            # dpkg: perl-modules
use List::MoreUtils qw(apply natatime);    # dpkg: liblist-moreutils-perl
use XML::Simple;                           # dpkg: libxml-simple-perl

# Get the nominal dimensions in pixels of an SVG in an XML::Simple object
sub svg_dimensions {
    my ($svg) = @_;
    if ( !$svg ) {
        croak('Was not passed legible SVG XML::Simple object');
    }
    my $dimensions = [];
    if (
        $svg->{viewBox} =~ m{
            ([\d.]+)  # Number (grouped)
            \s        # Space character
            ([\d.]+)  # Number (grouped)
            $         # End of string
        }smx
      )
    {
        $dimensions = [ $1, $2 ];
    }
    return $dimensions;
}

# Get the implicit translations in pixels of an SVG in an XML::Simple object
sub svg_translate {
    my ($svg) = @_;
    if ( !$svg ) {
        croak('Was not passed legible SVG XML::Simple object');
    }
    my $translate = [];
    if (
        $svg->{g}->{transform} =~ m{
            translate              # 'translate' keyword
            [(]                    # Opening parenthesis
            (-?[\d.]+),(-?[\d.]+)  # Two signed floating point numbers (each grouped)
            [)]                    # Closing parenthesis
        }smx
      )
    {
        $translate = [ $1, $2 ];
    }
    return $translate;
}

# Get the implicit scale factors in pixels of an SVG in an XML::Simple object
sub svg_scale {
    my ($svg) = @_;
    if ( !$svg ) {
        croak('Was not passed legible SVG XML::Simple object');
    }
    my $scale = [];
    if (
        $svg->{g}->{transform} =~ m{
            scale                  # 'scale' keyword
            [(]                    # Opening parenthesis
            (-?[\d.]+),(-?[\d.]+)  # Two signed floating point numbers (each grouped)
            [)]                    # Closing parenthesis
        }smx
      )
    {
        $scale = [ $1, $2 ];
    }
    return $scale;
}

# Get the latitude/longitude bounds of a GroundOverlay KML object
sub kml_groundoverlay_bounds {
    my ($kml) = @_;
    if ( !$kml ) {
        croak('Was not passed legible KML XML::Simple object');
    }
    my $bounds = {
        lat => {
            min => $kml->{GroundOverlay}->{LatLonBox}->{north},
            max => $kml->{GroundOverlay}->{LatLonBox}->{south}
        },
        lng => {
            min => $kml->{GroundOverlay}->{LatLonBox}->{west},
            max => $kml->{GroundOverlay}->{LatLonBox}->{east}
        },
    };
    return $bounds;
}

# Given SimpleXML objects for a KML (with GroundOverlay as the root object) and
# the image file to which it refers in SimpleXML SVG format, return an array of
# polygon coordinates
sub polygons {
    my ( $kml, $svg ) = @_;

    #
    # Check parameters.
    #
    if ( !$kml ) {
        croak('Was not passed legible KML XML::Simple object');
    }
    if ( !$svg ) {
        croak('Was not passed legible SVG XML::Simple object');
    }

    # Get the dimensions, transform, and scale of the image from the SVG
    my $dimensions = Inspire::Geo::svg_dimensions($svg);
    my $translate  = Inspire::Geo::svg_translate($svg);
    my $scale      = Inspire::Geo::svg_scale($svg);

    # Get the bounds of the image from the KML
    my $bounds = Inspire::Geo::kml_groundoverlay_bounds($kml);

    # Start an array of polygons; recurse through the paths, transforming all
    # the movements into absolute coordinates, and store them in pairs
    my $polygons = [];
    foreach my $path ( @{ $svg->{g}->{path} } ) {

        # Initialise structures
        my $coordinates = $path->{d};
        my $units = [ split m{\s}smx, $coordinates ];

        # A polygon is defined as a list of at least one linear ring of points.
        # The first ring is the exterior ring; the remaining optional rings are
        # interior rings
        my $polygon = [];
        my $ring    = [];

        # Recurse through all the movements, switching modes as appropriate
        my $relative = 0;
        my $position = [ 0, 0 ];
        my $complete = 0;
        my $iterator = natatime( 2, @{$units} );
        while ( my @cell = $iterator->() ) {
            my $point = \@cell;

            # Switch mode if we find a letter tells us so
            if ( $point->[0] =~ m{M}smx ) {
                $relative = 0;
            }
            elsif ( $point->[0] =~ m{l}smx ) {
                $relative = 1;
            }

            # If a letter tells us to close a curve, add this ring and start
            # a new one
            if ( $point->[1] =~ m{z}smx ) {
                $complete = 1;
            }

            # Filter out all letters
            $point = [
                apply {
                    s{
                [[:alpha:]]}
            {}gismx;
                    $_;
                }
                @{$point}
            ];

            # Depending on mode, either add or replace the current position
            if ($relative) {
                $point =
                  [ $position->[0] + $point->[0],
                    $position->[1] + $point->[1] ];
            }
            $position = $point;

            # Scale the point to the correct latitute and longitude
            my $geo = [ @{$point} ];

            # Scaling
            $geo = [ $geo->[0] * $scale->[0], $geo->[1] * $scale->[1] ];

            # Translating
            $geo = [ $geo->[0] + $translate->[0], $geo->[1] + $translate->[1] ];

            # Geocoding
            $geo->[0] =
              ( $geo->[0] / $dimensions->[0] ) *
              ( $bounds->{lng}->{max} - $bounds->{lng}->{min} ) +
              $bounds->{lng}->{min};
            $geo->[1] =
              ( $geo->[1] / $dimensions->[1] ) *
              ( $bounds->{lat}->{max} - $bounds->{lat}->{min} ) +
              $bounds->{lat}->{min};

            # Push point onto ring
            push @{$ring}, $geo;

            # Push ring onto polygon if it's finished
            if ($complete) {
                push @{$polygon}, $ring;
                $ring     = [];
                $complete = 0;
            }
        }

        # Push completed polygon onto collection
        push @{$polygons}, $polygon;
    }

    return $polygons;
}

# End package
1;

