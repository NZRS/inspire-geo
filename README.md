Inspire::Geo
============

Author
:   Tom Ryder <tom@sanctum.geek.nz>
Copyright
:   Inspire Net Ltd 2014
Version
:   1.3

Perl library and associated scripts for manipulating KML, KMZ, SVG, and PNG
files using XML::Simple and GDAL libraries. At the moment this is being used on
KMZ GroundOverlay objects (PNG overlays) to translate them into polygon forms
for database reference and drawing in Google Maps or Google Earth.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <http://www.gnu.org/licenses/>.

Dependencies
------------

*   Perl v5.10 or greater
*   Pragmas:
    -   autodie
    -   strict
    -   utf8
    -   warnings
*   Modules:
    -   Carp
    -   Cwd
    -   English
    -   File::Copy
    -   File::Temp
    -   File::Which
    -   Geo::OGR (1.7 or greater)
    -   Getopt::Long
    -   IO::Uncompress::Unzip
    -   List::MoreUtils
    -   Readonly
    -   XML::Simple
*   Other applications:
    -   convert(1) from the ImageMagick suite
    -   potrace(1)

On Debian Wheezy, this should do the trick:

    # aptitude install perl perl-base perl-modules \
        libfile-which-perl libgdal-perl liblist-moreutils-perl \
        libreadonly-perl libxml-simple-perl imagemagick \
        potrace

The Perl code all uses warnings and strict, and passes perlcritic --brutal.

Inspire::Geo::KMZGroundOverlayToShapefile (kmz-groundoverlay-to-shapefile)
--------------------------------------------------------------------------

This script converts a GroundOverlay object with georeferenced points in a KMZ
file to an ESRI shapefile set by way of tracing it to SVG and converting the
vectors while building the shapefile set with Geo::OGR. A WGS 84 projection
file is included in share/projection.prj.

The --source file should be a KMZ exported from Google Earth that contains a
single GroundOverlay object. An example file example.kmz showing a complex
polygon of wireless coverage over the North Island of New Zealand is included.
A screenshot is also included in share/doc/exporting-overlay-google-earth.png.

You will need to specify the path to the image file itself within the KMZ,
using the --image option. The script will not simply assume the first image it
finds is correct.

You can try an example run using the included example.kmz:

    $ cd inspire-geo
    $ perl -I lib bin/kmz-groundoverlay-to-shapefile \
        --source=share/example.kmz \
        --image=files/North\ Island\ coverage.png \
        --target=var/example-output \
        --shapefile=north-island-coverage \
        --projection=share/projection.prj

The shapefiles should then be generated in var/example-output, if everything's
working correctly.

Known problems
--------------

*   The binary calls are probably unnecessary. We should be trying to use
    ImageMagick's Perl bindings (PerlMagick). Same with libpotrace, if
    possible.
*   We shouldn't have to specify the filename within the KMZ. It might actually
    be better to check there's only one image in the KMZ, use it if so, throw
    our toys if there isn't.
*   I learned only just enough about georeferencing/projections to make this
    application work. There are likely shortcomings of which I'm unaware that
    need to be fixed by someone with a better understanding of how these work.

