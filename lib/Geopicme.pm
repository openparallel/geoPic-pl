
package Geopicme;

use Image::Magick;
use threads::tbb;
use threads::tbb::refcounter qw(Image::Magick);

use base qw(Exporter);

BEGIN { our @EXPORT = qw(resize_image) }

sub resize_image {
    my $img = shift;
    my $image = Image::Magick->new( debug => "Exception" );
    $image->Read("$img");
    my ($x, $y) = $image->Get(qw( columns rows ));

    my $smaller = ($x < $y ? $x : $y);
    $image->Crop(width => $smaller, height => $smaller,
		 gravity => "Center");
    $image->Resize( width => 160, height => 160,
		    filter => "Gaussian" );
    return $image;
}

1;
