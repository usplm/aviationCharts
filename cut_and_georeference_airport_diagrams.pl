#!/usr/bin/perl

# Cut out and georeference Caribbean insets from FAA aeronautical maps
# Based on the PDFs being rasterized at 300dpi
# Copyright (C) 2013  Jesse McGraw (jlmcgraw@gmail.com)
#
#--------------------------------------------------------------------------------------------------------------------------------------------
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see [http://www.gnu.org/licenses/].

#Standard modules
use strict;
use warnings;
use autodie;
use Carp;

#Using this so users don't need to globally install modules
#allows using "carton install" instead
use FindBin '$Bin';
use lib "$FindBin::Bin/local/lib/perl5";

#Non-Standard modules that should be installed locally
use Modern::Perl '2014';
use Params::Validate qw(:all);

#Call the main routine and exit with its return code
exit main(@ARGV);

sub main {
    our $debug = 0;
    my $chartType = 'airport_diagram';

    #I'm using locally compiled gdal
    #If your version is > 2 then set this to empty string ''
    our $compiled_gdal_dir = '';

    #     our $compiled_gdal_dir = '~/Documents/github/gdal/gdal/apps/';

    #Number of arguments supplied on command line
    my $num_args = $#ARGV + 1;

    if ( $num_args != 2 ) {
        say "Usage: $0 <destination_root_dir> <airport_diagram_directory>";
        exit;
    }

    # Get the base directory from command line
    my $destinationRoot        = $ARGV[0];
    my $linkedRastersDirectory = $ARGV[1];

    #     # For files that have a version in their name, this is where the links to the
    #     # lastest version will be stored
    #     my $linkedRastersDirectory = "airport_diagram_directory/";

    # Where clipped rasters are stored
    my $clippedRastersDirectory =
      "$destinationRoot/4_clippedRasters/$chartType/";

    # Where warped rasters are stored
    my $warpedRastersDirectory = "$destinationRoot/5_warpedRasters/$chartType/";

    # check that the directories exist
    unless ( -d $linkedRastersDirectory ) {
        die
          "Directory for source rasters doesn't exist: $linkedRastersDirectory";
    }

    unless ( -d $clippedRastersDirectory ) {
        die
          "Directory for clipped rasters doesn't exist: $clippedRastersDirectory";
    }
    unless ( -d $warpedRastersDirectory ) {
        die
          "Directory for warped_raster_directory rasters doesn't exist: $warpedRastersDirectory";
    }

    say "linkedRastersDirectory: $linkedRastersDirectory";
    say "clippedRastersDirectory: $clippedRastersDirectory ";
    say "warpedRastersDirectory: $warpedRastersDirectory";

    # The inset's name
    # Their source raster,
    # upper left X, upper left Y, lower right X, lower right Y pixel coordinates of the inset
    # The Ground Control Points for each inset
    #   Relative to the original, unclipped file: Pixel X, Pixel Y, Longitude, Latitude
    my %charts = (

        #GCPs are clockwise from upper left

        # New York (NY)
        #"00411_KSYR_AD" => [
        #    "00411ad",
        #    "74", "186", "1540", "2289",
        #    [
        #        "  910      420     76-07W 43-07N",
        #        "  1671     420     76-06W 43-07N",
        #        "  1671     1459    76-06W 43-06N",
        #        "  910      1459    76-07W 43-06N",
        #    ]
        #],

        # California (CA)
        "00281_KAPC_AD" => [
            "00281ad",
            "NAPA COUNTY",
            "74", "186", "1540", "2289",
            [
                "   480.1     359.8    122-17.0W 38-13.5N",
                "   1014.4    360.9    122-16.5W 38-13.5N",
                "   1014.4   1038.9    122-16.5W 38-13.0N",
                "   1015.4   1716.9    122-16.5W 38-12.5N",
                "   480.1    1718.0    122-17.0W 38-12.5N",
            ]
        ],
        "00294_KOAK_AD" => [
            "00294ad",
            "METRO OAKLAND INTL",
            "74", "186", "1540", "2289",
            [
                "   446.2     706.1    122-14W 37-44N",
                "   1025.6    704.3    122-13W 37-44N",
                "   1025.6   1433.4    122-13W 37-43N",
                "   1023.8   2163.3    122-13W 37-42N",
                "   446.2    2162.4    122-14W 37-42N",
            ]
        ],
        "00375_KSFO_AD" => [
            "00375ad",
            "SAN FRANCISCO INTL",
            "74", "186", "1540", "2289",
            [
                "   322       680     122-22W 37-38N",
                "   1006      680     122-22W 37-37N",
                "   1006     1765     122-24W 37-37N",
                "   323      1766     122-24W 37-38N",
                "   323      1222     122-23W 37-38N",
            ]
        ],
        "00410_KNUQ_AD" => [
            "00410ad",
            "MOFFETT FEDERAL AIRFIELD",
            "74", "186", "1540", "2289",
            [
                "   590.9     335.7     122-03W 37-26N",
                "   1457.6    335.7     122-02W 37-26N",
                "   1457.6   1422.9     122-02W 37-25N",
                "   590.3    1422.4     122-03W 37-25N",
            ]
        ],
        "00488_KSUU_AD" => [
            "00488ad",
            "TRAVIS AFB",
            "74", "186", "1540", "2289",
            [
                "   123.6     853.8     121-57W 38-17N",
                "   876.9     523.8     121-55W 38-17N",
                "   1086.2   1001.4     121-55W 38-16N",
                "   1295.1   1479.3     121-55W 38-15N",
                "   542.7    1809.9     121-57W 38-15N",
            ]
        ],
        "00693_KSJC_AD" => [
            "00693ad",
            "NORMAN Y MINETA SAN JOSE INTL",
            "74", "186", "1540", "2289",
            [
                "   623.8    957.7     121-56W 37-22N",
                "   1322.6   957.7     121-55W 37-22N",
                "   1321.5   1832.1    121-55W 37-21N",
                "   623.8    1831.0    121-56W 37-21N",
            ]
        ],
        "00696_KSTS_AD" => [
            "00696ad",
            "CHARLES M SCHULZ - SONOMA COUNTY",
            "74", "186", "1540", "2289",
            [
                "   495.4    657.7     122-49.0W 38-31.0N",
                "   1000.1   657.1     122-48.5W 38-31.0N",
                "   1000.6   1300.6    122-48.5W 38-30.5N",
                "   1000.6   1942.9    122-48.5W 38-30.0N",
                "   496.0    1943.5    122-49.0W 38-30.0N",
            ]
        ],
        "05015_KHWD_AD" => [
            "05015ad",
            "HAYWARD EXEC",
            "74", "186", "1540", "2289",
            [
                "   103.8    760.3     122-07.0W 37-40.0N",
                "   989.1    760.3     122-07.0W 37-39.5N",
                "   989.1    1464.6    122-07.5W 37-39.5N",
                "   104.9    1465.7    122-07.5W 37-40.0N",
            ]
        ],
        "05320_KCCR_AD" => [
            "05320ad",
            "BUCHANAN FLD",
            "74", "186", "1540", "2289",
            [
                "   674.6    905.6     122-3.5W 37-59.5N",
                "   1384.5   905.6     122-3.0W 37-59.5N",
                "   1384.5   1801.1    122-3.0W 37-59.0N",
                "   674.6    1801.1    122-3.5W 37-59.0N",
            ]
        ],
        "06075_KLVK_AD" => [
            "06075ad",
            "LIVERMORE MUNI",
            "74", "186", "1540", "2289",
            [
                "   201.4    482.7     121-48.5W 37-42.0N",
                "   1042.9   481.6     121-48.5W 37-41.5N",
                "   1042.9   1150.8    121-49.0W 37-41.5N",
                "   1042.9   1817.9    121-49.5W 37-41.5N",
                "   201.4    1817.9    121-49.5W 37-42.0N",
            ]
        ],
        "09216_KPAO_AD" => [
            "09216ad",
            "PALO ALTO",
            "74", "186", "1540", "2289",
            [
                "   528.3    228.2     122-07.0W 37-28.0N",
                "   1496.0   227.1     122-06.5W 37-28.0N",
                "   1496.0   1442.7    122-06.5W 37-27.5N",
                "   528.3    1442.7    122-07.0W 37-27.5N",
            ]
        ],
        "09219_KSQL_AD" => [
            "09219ad",
            "SAN CARLOS",
            "74", "186", "1540", "2289",
            [
                "   643.5    653.9     122-15.0W 37-31.0N",
                "   1510.2   653.9     122-14.5W 37-31.0N",
                "   1510.2   1741.1    122-14.5W 37-30.5N",
                "   643.5    1740.0    122-15.0W 37-30.5N",
            ]
        ],
    );

    foreach my $destination_chart_name ( sort keys %charts ) {

        #$destination_chart_name is what we'll call the final chart
        #Pull out the relevant data for each inset
        my $sourceRaster =
          $linkedRastersDirectory . $charts{$destination_chart_name}[0];
        my $ulX         = $charts{$destination_chart_name}[2];
        my $ulY         = $charts{$destination_chart_name}[3];
        my $lrX         = $charts{$destination_chart_name}[4];
        my $lrY         = $charts{$destination_chart_name}[5];
        my $gcpArrayRef = $charts{$destination_chart_name}[6];

        my $clipped_raster =
          $clippedRastersDirectory . $destination_chart_name . ".vrt";
        my $warped_raster =
          $warpedRastersDirectory . $destination_chart_name . ".tif";
        say $destination_chart_name;

        #create the string of ground control points
        my $gcpString = createGcpString( $gcpArrayRef, $ulX, $ulY );

        #cut out the inset from source raster and add GCPs
        cutOutInsetFromSourceRaster( $sourceRaster, $ulX, $ulY, $lrX, $lrY,
            $gcpString, $clipped_raster );

        #warp and georeference the clipped file
        warpRaster( $clipped_raster, $warped_raster );
    }
    return 0;
}

sub coordinateToDecimal {

    my ( $deg, $min, $sec, $declination ) = validate_pos(
        @_,
        { type => SCALAR },
        { type => SCALAR },
        { type => SCALAR },
        { type => SCALAR }
    );

    my $signeddegrees;

    return "" if !( $declination =~ /[NSEW]/i );

    $deg = $deg / 1;
    $min = $min / 60;
    $sec = $sec / 3600;

    $signeddegrees = ( $deg + $min + $sec );

    if ( ( $declination =~ /[SW]/i ) ) {
        $signeddegrees = -($signeddegrees);
    }

    given ($declination) {
        when (/N|S/) {

            #Latitude is invalid if less than -90  or greater than 90
            $signeddegrees = "" if ( abs($signeddegrees) > 90 );
        }
        when (/E|W/) {

            #Longitude is invalid if less than -180 or greater than 180
            $signeddegrees = "" if ( abs($signeddegrees) > 180 );
        }
        default {
        }

    }

    say "Deg: $deg, Min:$min, Sec:$sec, Decl:$declination -> $signeddegrees"
      if $main::debug;
    return ($signeddegrees);
}

sub cutOutInsetFromSourceRaster {
    my ( $sourceRaster, $ulX, $ulY, $lrX, $lrY, $gcpString, $destinationRaster )
      = validate_pos(
        @_,
        { type => SCALAR },
        { type => SCALAR },
        { type => SCALAR },
        { type => SCALAR },
        { type => SCALAR },
        { type => SCALAR },
        { type => SCALAR },
      );

    say "\tClip: $sourceRaster -> $destinationRaster, $ulX, $ulY, $lrX, $lrY";

    #Create the source window string for gdal
    my $srcWin =
      $ulX . " " . $ulY . " " . eval( $lrX - $ulX ) . " " . eval( $lrY - $ulY );

    #     say $srcWin;

    #Assemble the command
    #Note the "pdf" added in to the file name since I'm to lazy to cut it out earlier
    my $gdal_translateCommand =
        './memoize.py '
      . $main::compiled_gdal_dir
      . "gdal_translate \\
      -strict \\
      -of VRT \\
      -srcwin $srcWin \\
      -a_srs WGS84 \\
      $gcpString \\
      '$sourceRaster.PDF.tif' \\
      '$destinationRaster'";

    if ($main::debug) {
        say $gdal_translateCommand;
        say "";
    }

    #Run gdal_translate
    my $gdal_translateoutput = qx($gdal_translateCommand);

    my $retval = $? >> 8;

    if ( $retval != 0 ) {
        carp
          "Error executing gdal_translate.  Is it installed? Return code was $retval";
        croak "return code: $retval";
    }
    say $gdal_translateoutput if $main::debug;

    return;

}

sub warpRaster {
    my ( $sourceRaster, $destinationRaster ) =
      validate_pos( @_, { type => SCALAR }, { type => SCALAR }, );

    say "\twarp: $sourceRaster -> $destinationRaster";

    #Assemble the command
    my $gdalWarpCommand =
        './memoize.py '
      . $main::compiled_gdal_dir
      . "gdalwarp \\
         -t_srs WGS84 \\
         -r lanczos \\
         -dstalpha \\
         -overwrite \\
         $sourceRaster \\
         $destinationRaster";

    if ($main::debug) {
        say $gdalWarpCommand;
        say "";
    }

    #Run gdalwarp
    my $gdalWarpOutput = qx($gdalWarpCommand);

    my $retval = $? >> 8;

    if ( $retval != 0 ) {
        carp "Error executing gdalwarp.  Return code was $retval";
        return $retval;
    }
    say $gdalWarpOutput if $main::debug;

    say "\tOverviews: $sourceRaster -> $destinationRaster";

    my $gdaladdoCommand =
        './memoize.py '
      . $main::compiled_gdal_dir
      . "gdaladdo \\
        -ro \\
        -r gauss \\
        --config INTERLEAVE_OVERVIEW PIXEL \\
        --config COMPRESS_OVERVIEW JPEG \\
        --config BIGTIFF_OVERVIEW IF_NEEDED \\
         $destinationRaster \\
        2 4 8 16 32 64";

    if ($main::debug) {
        say $gdaladdoCommand;
        say "";
    }

    #Run gdalwarp
    my $gdaladdoOutput = qx($gdaladdoCommand);

    $retval = $? >> 8;

    if ( $retval != 0 ) {
        carp "Error executing gdalwarp.  Return code was $retval";
        return $retval;
    }
    say $gdaladdoOutput if $main::debug;

    return;
}

sub createGcpString {
    my ( $gcpArrayRef, $ul_x, $ul_y ) = validate_pos(
        @_,
        { type => ARRAYREF },
        { type => SCALAR },
        { type => SCALAR },
    );
    my $gcpString = "";

    #Create the gcpString from the array of gcp entries
    foreach (@$gcpArrayRef) {
        my ( $lonDecimal, $latDecimal );

        #Pull out components
        $_ =~ m/
              (?<rasterX>\d+[.]?\d*) \s+
              (?<rasterY>\d+[.]?\d*) \s+
              (?<lonDegrees>\d{2,}) - (?<lonMinutes>\d+[.]?\d*) (?<lonDeclination>[E|W]) \s+
              (?<latDegrees>\d{2,}) - (?<latMinutes>\d+[.]?\d*) (?<latDeclination>[N|S])
              /ix;

        #Make these pixel coordinates relative to the smaller window of the inset
        my $rasterX = $+{rasterX} - $ul_x;
        my $rasterY = $+{rasterY} - $ul_y;

        my $lonDegrees     = $+{lonDegrees};
        my $lonMinutes     = $+{lonMinutes};
        my $lonSeconds     = 0;
        my $lonDeclination = $+{lonDeclination};

        my $latDegrees     = $+{latDegrees};
        my $latMinutes     = $+{latMinutes};
        my $latSeconds     = 0;
        my $latDeclination = $+{latDeclination};

        say
          "$lonDegrees-$lonMinutes-$lonSeconds-$lonDeclination,$latDegrees-$latMinutes-$latSeconds-$latDeclination"
          if $main::debug;

        #If all seems ok, convert to decimal
        if (   $lonDegrees
            && $lonMinutes
            && $lonDeclination
            && $latDegrees
            && $latMinutes
            && $latDeclination )
        {
            $lonDecimal =
              coordinateToDecimal( $lonDegrees, $lonMinutes, $lonSeconds,
                $lonDeclination );
            $latDecimal =
              coordinateToDecimal( $latDegrees, $latMinutes, $latSeconds,
                $latDeclination );
        }
        else {
            die "Missing some part of coordinate";
        }
        say "$lonDecimal, $latDecimal" if $main::debug;

        #Add it to the overall GCP string
        $gcpString =
          $gcpString . "-gcp $rasterX $rasterY $lonDecimal $latDecimal ";
    }

    say "gcpString: $gcpString" if $main::debug;
    return $gcpString;
}
