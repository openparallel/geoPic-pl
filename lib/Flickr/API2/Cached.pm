

=head1 NAME

Flickr::API2::Cached - simple cache module for specific flickr API requests

=head1 SYNOPSIS

 use Flickr::API2::Cached;

 my $flickr = new Flickr::API2::Cached(
     {'key' => '76904a42e0e0a2b7eeaf037c8ec2e00b',
      'secret' => 'b4d1a53c3463051a'},
     '/tmp/flickrcache',  # optional
 );

 $flickr->cached_method(
      $key, 'flickr.photos.search', {
	    lat => $lat,
	    lon => $lon,
	    min_taken_date => 1262304000,
	    accuracy => 3,
	    has_geo => 1,
	}
    );

 # get a thumbnail image; pass in a URL or a image hash / size
 # selector.  returns a filename for the cached image.
 $flickr->get_image_from_cache($img, "t");

=head1 DESCRIPTION

This module just caches calls to the Flickr2 API.  You have to
determine the uniqueness means yourself, by generating the key.

If you don't specify the cache directory, a temporary one is created,
caching uses within the same invocation of the script only.

The cache expiry is fixed at 24 hours, sorry :-)

Images are cached forever; clean up all files older than a certain
time yourself to keep the cache directory small and respect the
copyright of the source images.

=cut

package Flickr::API2::Cached;

use base qw(Flickr::API2);
use File::Temp qw(tempdir);

sub new {
    my $package = shift;
    my $super_args = shift;
    my $cache_dir = shift || tempdir( CLEANUP => 1 );
    my $self = $package->SUPER::new($super_args);

    $self->{cache_dir} = $cache_dir;
    return $self;
}

use Digest::MD5 qw(md5_hex);
use JSON::XS;
use Fatal qw(:void open close);
use LWP::Simple qw(getstore);

sub load_json {
    my $filename = shift;
    open my $json, "<", $filename;
    binmode $json, ":utf8";
    local $/;
    my $json_text = <$json>;
    return decode_json $json_text;
}

sub store_json {
    my $filename = shift;
    my $data = shift;
    my $json_text = encode_json( $data );

    open my $json, ">", $filename;
    binmode $json, ":utf8";
    print { $json } $json_text;
    close $json;
}

sub cached_method {
    my $self = shift;
    my $key = shift;
    my $cache_filename = $self->{cache_dir}."/".substr(md5_hex($key),0,12).".json";
    if ( -f $cache_filename ) {
	my $stat = [stat _];
	if ( (time - $stat->[9]) < 86400 ) {
	    my $info = load_json($cache_filename);
	    return $info->{response};
	}
    }
    my $request = [ @_ ];
    my $response = $self->execute_method( @_ );
    store_json(
	$cache_filename,
	{ request => $request,
	  response => $response },
    );
    return $response;
}

sub get_url_from_image {
    my $self = shift;
    my $image_h = shift;
    my $size = shift;
    my $image_url;
    if ( !ref $image_h ) {
	$image_url = $image_h;
    }
    else {
	$image_url ='http://farm'.$image_h->{farm}.'.static.flickr.com/'
	    .$image_h->{server}.'/'.$image_h->{id}
		.'_'.$image_h->{secret}.'_'.$size.'.jpg'
    }
    return $image_url;
}

sub get_image_from_cache {
    my $self = shift;
    my $image_url = $self->get_url_from_image(@_);
    $image_url =~ m{(.*)(_.\.jpg)$} or die "only jpeg images supported: $image_url";
    my $cache_filename = $self->{cache_dir}."/"
	.substr(md5_hex($1),0,12).$2;

    if ( -f $cache_filename ) {
	return $cache_filename;
    }
    my $response = getstore($image_url, $cache_filename);
    if ( $response !~ m{^2} ) {
	unlink($cache_filename);
	die "got response $response fetching $image_url";
    }
    return $cache_filename;
}

1;
