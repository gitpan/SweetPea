use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'SweetPea',
    AUTHOR              => q{Al Newkirk <al.newkirk@awnstudio.com>},
    VERSION_FROM        => 'lib/SweetPea.pm',
    ABSTRACT_FROM       => 'lib/SweetPea.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'CGI' => 1,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SweetPea-*' },
);
